"""Fails while the traces-drilldown breakdown-header bug (fixed upstream by PR #873) exists:
  - panel menu is show-on-hover, so an invisible ~24px slot sits empty in every breakdown panel header
  - Include/Exclude is a bordered segmented group ("Add to filters") crowding the title
Run: demo/repro-check.sh   (stack: demo/start.sh; re-seeds Tempo first)"""
import os, sys, json
from playwright.sync_api import sync_playwright
HERE = os.path.dirname(os.path.abspath(__file__))
URL = (f"http://127.0.0.1:{os.environ.get('GRAFANA_PORT','3330')}/a/grafana-exploretraces-app/explore"
       "?from=now-1h&to=now&var-ds=tempo&var-primarySignal=nestedSetParent%3C0&var-metric=rate"
       "&var-groupBy=span.http.route&actionView=breakdown")

def run(name="check"):
    with sync_playwright() as p:
        b = p.chromium.launch(args=["--no-sandbox"], **({"executable_path": os.environ["CHROME"]} if os.environ.get("CHROME") else {}))
        pg = b.new_page(viewport={"width": 1440, "height": 900})
        pg.goto(URL, wait_until="load", timeout=90000)
        pg.wait_for_selector("[data-testid='data-testid header-container']:has-text('Exclude')", timeout=60000)
        pg.wait_for_timeout(4000)
        pg.mouse.move(5, 890)  # no hover on any panel
        hdrs = pg.evaluate("""() => [...document.querySelectorAll('[data-testid="data-testid header-container"]')]
          .filter(h => h.textContent.includes('Exclude')).map(h => {
            const m = h.querySelector('[data-testid^="data-testid Panel menu"]'); const r = h.getBoundingClientRect();
            return {title: (h.querySelector('h2')||{}).textContent, menuVisible: !!m && getComputedStyle(m).visibility !== 'hidden'
                      && getComputedStyle(m).opacity !== '0', segmentedGroup: !!h.querySelector('[role=group][aria-label="Add to filters"]'),
                    box: {x: r.x, y: r.y, width: r.width, height: r.height}}; })""")
        pg.screenshot(path=os.path.join(HERE, f"{name}.png"))
        if hdrs:
            bx = hdrs[0]["box"]; pg.screenshot(path=os.path.join(HERE, f"{name}-crop.png"),
                clip={"x": bx["x"] - 6, "y": bx["y"] - 6, "width": bx["width"] + 12, "height": bx["height"] + 12})
        b.close()
    assert hdrs, "no breakdown panels found - is Tempo seeded?"
    bad = [{k: h[k] for k in ("title", "menuVisible", "segmentedGroup")} for h in hdrs if not h["menuVisible"] or h["segmentedGroup"]]
    assert not bad, f"{len(bad)}/{len(hdrs)} breakdown headers have a hidden hover-menu slot and/or segmented Include/Exclude:\n" + json.dumps(bad, indent=1)
    print(f"PASS: {len(hdrs)} breakdown headers show the menu and plain Include/Exclude buttons")

if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "check")
