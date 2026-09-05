#!/usr/bin/env python3
"""
Étape "une fois avec ordinateur" : génère le fichier de pairing nécessaire
au tunnel loopback, en s'appuyant sur pymobiledevice3 (qui implémente le
même protocole que Jitterbug/libimobiledevice pour établir un pairing de confiance).

Usage :
    pip install pymobiledevice3
    python3 generate_pairing.py --output pairing.plist

Puis transfère pairing.plist sur l'iPhone (AirDrop, câble, Fichiers) et
importe-le dans l'app via AddAppView / PairingManager.importPairingFile.
"""
import argparse
import plistlib
import sys

try:
    from pymobiledevice3.lockdown import create_using_usbmux
except ImportError:
    print("Installe d'abord : pip install pymobiledevice3", file=sys.stderr)
    sys.exit(1)


def generate_pairing_record(output_path: str) -> None:
    """
    Se connecte au device via USB, établit (ou récupère) le pairing record
    usbmuxd standard, et l'exporte au format attendu par minimuxer côté iOS.
    """
    lockdown = create_using_usbmux()
    print(f"Device connecté : {lockdown.udid} ({lockdown.product_type})")

    pairing_record = lockdown.pair_record
    if pairing_record is None:
        print("Aucun pairing existant — lance le pairing (accepte la popup 'Trust' sur l'iPhone)")
        lockdown.pair()
        pairing_record = lockdown.pair_record

    with open(output_path, "wb") as f:
        plistlib.dump(pairing_record, f)

    print(f"Pairing file écrit dans {output_path}")
    print("Transfère ce fichier sur l'iPhone et importe-le dans l'app.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="pairing.plist")
    args = parser.parse_args()
    generate_pairing_record(args.output)
