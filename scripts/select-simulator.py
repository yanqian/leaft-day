#!/usr/bin/env python3
"""Validate native simctl inventory; never create or boot a device."""
import json
import os
import re
import sys
import uuid


def select_device(data, requested=None):
    if not isinstance(data, dict) or not isinstance(data.get('runtimes'), list) or not isinstance(data.get('devices'), dict) or not isinstance(data.get('devicetypes'), list):
        raise ValueError('Unrecognized simctl inventory schema')
    families = {t['identifier']: t.get('productFamily') for t in data['devicetypes'] if isinstance(t, dict) and isinstance(t.get('identifier'), str)}
    candidates = []
    for runtime in data['runtimes']:
        if not isinstance(runtime, dict):
            raise ValueError('Malformed runtime entry')
        if runtime.get('platform') != 'iOS' or runtime.get('isAvailable') is not True:
            continue
        version = runtime.get('version')
        if not isinstance(version, str) or not re.fullmatch(r'\d+(\.\d+)*', version):
            raise ValueError('Unrecognized runtime version')
        parts = tuple(map(int, version.split('.')))
        if parts[0] < 26:
            continue
        identifier = runtime.get('identifier')
        if not isinstance(identifier, str):
            raise ValueError('Missing runtime identifier')
        devices = data['devices'].get(identifier, [])
        if not isinstance(devices, list):
            raise ValueError('Malformed device list')
        for device in devices:
            if not isinstance(device, dict):
                raise ValueError('Malformed device entry')
            if device.get('isAvailable') is not True or families.get(device.get('deviceTypeIdentifier')) != 'iPhone':
                continue
            udid = device.get('udid')
            if not isinstance(udid, str):
                raise ValueError('Missing device UDID')
            uuid.UUID(udid)
            if requested and udid.lower() != requested.lower():
                continue
            if not isinstance(device.get('name'), str) or device.get('state') not in ('Booted', 'Shutdown'):
                continue
            candidates.append((parts, device, runtime))
    if not candidates:
        raise ValueError('No available iOS 26+ iPhone matches the requested inventory/UDID')
    candidates.sort(key=lambda x: (tuple(-n for n in x[0]), x[1]['name'], x[1]['udid']))
    _, device, runtime = candidates[0]
    return {'name': device['name'], 'udid': device['udid'], 'state': device['state'], 'runtime': runtime['identifier'], 'version': runtime['version']}


if __name__ == '__main__':
    try:
        print(json.dumps(select_device(json.load(sys.stdin), os.environ.get('SWIPE_SIMULATOR_UDID')), ensure_ascii=False))
    except (ValueError, TypeError, KeyError) as error:
        print(f'NOT_READY: {error}', file=sys.stderr)
        sys.exit(1)
