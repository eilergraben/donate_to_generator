# donate_to_generator
delete existing consolidations with donate_to/input and reasign with donate_to_multi/input_multi
📄 README

Donate_to Script – Anleitung

Dieses Script dient dazu, mehrere donate_to-Requests an den Midnight Scavenger API-Endpunkt zu senden.
Es verwendet Daten aus einer Datei namens input.txt und erstellt automatisch ein Logfile.

📁 Dateien im Ordner

donate_to.ps1
Das PowerShell-Script, das die Requests ausführt.

input.txt
Die Datei, in der Recipient-Adresse, Donor-Adressen und deren Signatures definiert sind.

/logs/
Ordner, in dem automatisch Logfiles erstellt werden.

📝 Format der input.txt

Recipient address: <RECIPIENT_ADDRESS>

Donor: <DONOR_1>
Signiture: <SIGNATURE_1>

Donor: <DONOR_2>
Signiture: <SIGNATURE_2>

...

Beispiel:

Recipient address: addr1qy...

Donor: addr1qx...
Signiture: eyJh...

Donor: addr1zz...
Signiture: eyJh...



🖊️ Wie erhalte ich eine Signatur in ETERNL?

Eternl oeffnen

Settings -> App Utilities -> Sign Data

In das Textfeld "Payload (data to sign)" exact diese Nachricht einfuegen:

Assign accumulated Scavenger rights to: <recipient_address>


Donor Adresse in "Address or ID) einfügen (achte darauf, dass es die payment address ist, nicht die staking address)

Signieren

Eternl zeigt eine Signatur, die so beginnt:

eyJh...


Kopiere diese Signatur in input.txt


[X] Wichtiger Hinweis: Bestehende Consolidation loeschen

Wenn du eine bereits ausgefuehrte oder fehlerhafte Consolidation zuruecksetzen oder loeschen moechtest, fuehre einfach eine neue donate_to-Anfrage aus, bei der Donor und Recipient die gleiche Adresse sind:

Recipient address: <DONOR_1>
Donor: <DONOR_1>
Signiture: <SIGNATUR_VON_DONOR_1xDONOR_1>

Dies teilt dem Midnight-System mit, dass die Scavenger-Rechte an dieselbe Adresse zurueckgegeben werden sollen.
Damit wird die vorherige Consolidation effektiv aufgehoben bzw. neutralisiert.

Wichtig:

Die Signatur muss trotzdem korrekt neu generiert werden.

Jede Adresse benoetigt ihre eigene gueltige Signatur, auch wenn Recipient und Donor identisch sind.

▶️ Script ausführen

Neues PowerShell-Fenster im selben Ordner öffnen, in dem die Dateien donate_to.ps1 und Input.txt einthalten sind

Script starten:

.\donate_to.ps1


🔐 Sicherheit

Die Signatures in input.txt sind sensible Daten und sollten niemals weitergegeben werden.

input.txt sollte nicht in Cloud-Ordnern (OneDrive, Dropbox etc.) gespeichert werden.

Logfiles enthalten keine privaten Keys oder Signatures.

⚠️ Fehlerbehandlung

Das Script reagiert auf:

Netzwerkfehler

Serverantworten mit Fehlercodes

Fehlende Signatures

Ungueltige input.txt

Wenn ein Donor-Block unvollstaendig ist:
wird dieser Block uebersprungen
das Script laeuft mit den übrigen Eintragen weiter

🔄 Typische Probleme

Problem: Script startet nicht und sagt „execution of scripts is disabled“
→ In PowerShell ausführen:

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
