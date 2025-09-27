import subprocess

def test_wg_installed():
    result = subprocess.run(["wg", "--version"], capture_output=True, text=True)
    assert result.returncode == 0
    assert "WireGuard" in result.stdout