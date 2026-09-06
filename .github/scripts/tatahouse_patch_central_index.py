from pathlib import Path

p = Path('compliance/kpis/tatahouse/index.html')
s = p.read_text(encoding='utf-8')
marker = '      <!-- Nosso Propósito -->'

if 'data-tatahouse-central="v1"' in s:
    raise SystemExit('Central entry already present; refusing duplicate patch')
if s.count(marker) != 1:
    raise SystemExit(f'Expected exactly one insertion marker, found {s.count(marker)}')

bloco = '''      <!-- Central TATÁ House — shell governado do produto oficial -->
      <div class="ac-dept-chip active-chip" data-tatahouse-central="v1" onclick="location.href='central.html'" style="cursor:pointer">
        <div class="ac-chip-icon">
          <svg viewBox="0 0 24 24"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/><path d="M9 21v-7h6v7"/></svg>
        </div>
        <span class="ac-chip-label">Central TATÁ House</span>
      </div>

'''

p.write_text(s.replace(marker, bloco + marker), encoding='utf-8')
