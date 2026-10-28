"""Seria symulacji meczu na kilku parach taktyk (równolegle) i zbiorcza tabela do kalibracji (krok B4 planu
docs/design/match_v2_plan.md): gole, strzały, posiadania dochodzące do strefy 5, akcje skrzydłami, wyczerpani,
obrony bramkarza, wyniki oraz średnia liczba zagrań każdej karty.

Użycie (z katalogu projektu):
    python tools/sim_batch.py [matches=150] [seed=1] [out=<katalog na pełne raporty>] [dowolne argumenty match_sim]
Ścieżka Godota: zmienna środowiskowa GODOT albo domyślna poniżej.
"""
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

GODOT = os.environ.get('GODOT', r'E:\GameDev\Godot\Godot_v4.7.2-stable_win64_console.exe')
TACTICS = ['t_442', 't_451', 't_433', 't_352', 't_451_am', 't_352_am', 't_433_dm', 't_433_am']
# Para domyślna (składy z GameState), mecze każdej taktyki z samą sobą i dwie pary mieszane.
CONFIGS = [('default', [])] + [(t, ['home_tactic=' + t, 'away_tactic=' + t]) for t in TACTICS] + [
    ('442v451', ['home_tactic=t_442', 'away_tactic=t_451']),
    ('352amv433', ['home_tactic=t_352_am', 'away_tactic=t_433']),
]


def main() -> None:
    options = {'matches': '150', 'seed': '1', 'out': ''}
    extra = []
    for arg in sys.argv[1:]:
        key = arg.split('=', 1)[0]
        if key in options:
            options[key] = arg.split('=', 1)[1]
        else:
            extra.append(arg)

    def run(config):
        name, args = config
        command = [GODOT, '--headless', '--path', '.', 'res://scenes/dev/match_sim.tscn', '--',
                   'matches=' + options['matches'], 'seed=' + options['seed']] + args + extra
        output = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace').stdout
        if options['out']:
            os.makedirs(options['out'], exist_ok=True)
            with open(os.path.join(options['out'], name + '.txt'), 'w', encoding='utf-8') as file:
                file.write(output)
        return name, output

    with ThreadPoolExecutor(max_workers=max((os.cpu_count() or 2) - 1, 1)) as pool:
        results = list(pool.map(run, CONFIGS))

    def grab(pattern, text, cast=float, default=None):
        match = re.search(pattern, text)
        return cast(match.group(1)) if match else default

    cards = {}
    totals = {'goals': 0.0, 'shots': 0.0, 'reach': 0.0}
    print('%-10s %5s %5s %5s %4s %4s %5s %5s %s' % ('para', 'gole', 'strz', 'z5%', 'L%', 'R%', 'wycz', 'GKsv',
                                                    'wyniki (dom/remis/wyjazd)'))
    for name, output in results:
        goals = grab(r'Gole / mecz: ([\d.]+)', output)
        if goals is None:
            print('%-10s BŁĄD:\n%s' % (name, output[-600:]))
            continue
        shots = re.search(r'Strzały / mecz: \S+ ([\d.]+), \S+ ([\d.]+)', output)
        shot_total = float(shots.group(1)) + float(shots.group(2))
        reach = grab(r'Postęp posiadania.* 5:(\d+)%', output, int)
        lanes = re.search(r'korytarz L (\d+)% C \d+% R (\d+)%', output)
        exhausted = grab(r'wyczerpani na koniec (\d+)%', output, int)
        saves = grab(r'goalkeeper_save ([\d.]+)', output, float, 0.0)
        wins = re.search(r'Wyniki: \S+ (\d+), remisy (\d+), \S+ (\d+)', output)
        totals['goals'] += goals
        totals['shots'] += shot_total
        totals['reach'] += reach
        print('%-10s %5.2f %5.1f %5d %4s %4s %5d %5.1f %s' % (name, goals, shot_total, reach, lanes.group(1),
                                                            lanes.group(2), exhausted, saves, '/'.join(wins.groups())))
        for line in output.splitlines():
            match = re.match(r'^(\w+)\s+([\d.]+) \|', line)
            if match and match.group(1) != 'karta':
                cards.setdefault(match.group(1), []).append(float(match.group(2)))
    count = len(results)
    print('%-10s %5.2f %5.1f %5.0f' % ('średnio', totals['goals'] / count, totals['shots'] / count,
                                       totals['reach'] / count))
    print()
    print('Karty – zagrania / mecz (średnio po parach; min–max):')
    for card, values in sorted(cards.items(), key=lambda item: -sum(item[1])):
        print('  %-16s %5.2f  (%.2f–%.2f)' % (card, sum(values) / count, min(values), max(values)))


if __name__ == '__main__':
    main()
