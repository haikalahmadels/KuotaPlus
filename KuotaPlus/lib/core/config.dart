/// Diisi lewat `--dart-define-from-file=env/<target>.json` (docs/TECH-KuotaPlus.md).
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost');
