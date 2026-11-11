"""Run the Swift encrypted bridge against the real API using a disposable fixture."""
import subprocess
from pathlib import Path
from test_companion import CompanionTest

fixture = CompanionTest()
fixture.setUp()
try:
    binary = Path(__file__).resolve().parents[1] / 'work/nearby-validation/nearby-api-tests'
    subprocess.run([str(binary), str(fixture.server.server_port), fixture.temp.name], check=True)
    # All prior-session files are recoverable in this fixture's fake Trash.
    assert len(list(fixture.store.trash.rglob('*.png'))) == 2
    assert (fixture.store.library / 'Inbox/new.png').is_file()
finally:
    fixture.tearDown()
