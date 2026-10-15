#!/usr/bin/env python3
"""Measure an isolated Debug app's launch, without display or login side effects."""
import argparse
import pathlib
import statistics
import plistlib
import select
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('app', type=pathlib.Path)
parser.add_argument('--runs', type=int, default=10)
args = parser.parse_args()
with (args.app / 'Contents/Info.plist').open('rb') as handle:
    identifier = plistlib.load(handle).get('CFBundleIdentifier', '')
if identifier != 'com.cohen.ember.performance':
    raise SystemExit('Use the isolated com.cohen.ember.performance Debug bundle.')
executable = args.app / 'Contents/MacOS/Ember'
samples = []
for index in range(args.runs):
    start = time.perf_counter()
    process = subprocess.Popen([str(executable), 'xctest-benchmark-startup'],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    marker = None
    deadline = start + 30
    try:
        while time.perf_counter() < deadline:
            if not select.select([process.stdout], [], [], max(0, deadline - time.perf_counter()))[0]:
                break
            line = process.stdout.readline()
            if not line:
                break
            if line.startswith('EMBER_STARTUP '):
                marker = line.strip()
                break
        elapsed = (time.perf_counter() - start) * 1000
        if marker is None:
            raise SystemExit('Debug startup marker missing; use an isolated Debug bundle.')
        process.wait(timeout=30)
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
    samples.append(elapsed)
    print(f'run={index + 1} process_to_ready_ms={elapsed:.3f} {marker}', flush=True)
print(f'process_to_ready median_ms={statistics.median(samples):.3f} max_ms={max(samples):.3f}')
