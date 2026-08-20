const names = ['Red','Orange','Yellow','Green','Cyan','Blue','Magenta'];
const surfaceNames = [['Darker','DarkerBackground'],['Dark','DarkBackground'],['Background','Background'],['Lighter','LighterBackground']];

const css = (node, palette) => {
  for (const [key, value] of Object.entries(palette)) {
    node.style.setProperty(`--${key[0].toLowerCase()+key.slice(1)}`, value);
  }
};

function renderVariant(node, label, palette) {
  node.querySelector('.variant-title').textContent = label;
  css(node, palette);
  node.querySelector('.surfaces').innerHTML = surfaceNames.map(([name, key]) => `<span class="surface" style="background:${palette[key]}">${name}</span>`).join('');
  node.querySelector('.text-samples').innerHTML = `<p class="foreground">Foreground text</p><p class="muted">Muted text</p><div class="chips"><span class="accent">Accent</span><span class="selection">Selection</span></div>`;
  node.querySelector('.ansi').innerHTML = names.map(key => `<span style="background:${palette[key]}">${key}</span>`).concat(names.slice(0,6).map(key => `<span class="bright" style="background:${palette['Bright'+key]}">bright ${key}</span>`)).join('');
}

function render(item) {
  const node = document.querySelector('#preview-template').content.cloneNode(true);
  const article = node.querySelector('.preview');
  article.querySelector('h2').textContent = `${item.name} · ${item.representatives.length} reps`;
  const image = article.querySelector('img');
  image.src = item.image;
  image.alt = item.name;
  renderVariant(article.querySelector('.source'), 'SOURCE', item.source_palette);
  renderVariant(article.querySelector('.calm'), 'CALM', item.calm_palette);
  renderVariant(article.querySelector('.mute'), 'MUTE', item.mute_palette);
  renderVariant(article.querySelector('.deep'), 'DEEP', item.deep_palette);
  renderVariant(article.querySelector('.vibrant'), 'VIBRANT', item.vibrant_palette);
  renderVariant(article.querySelector('.balanced'), 'BALANCED', item.balanced_palette);
  const json = JSON.stringify({harmony: item.harmony, image: item.image, representatives: item.representatives, source_palette: item.source_palette, calm_palette: item.calm_palette, mute_palette: item.mute_palette, deep_palette: item.deep_palette, vibrant_palette: item.vibrant_palette, balanced_palette: item.balanced_palette}, null, 2);
  article.querySelector('pre').textContent = json;
  const copyButton = article.querySelector('.copy-json');
  const copyStatus = article.querySelector('.copy-status');
  copyButton.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(json);
      copyButton.textContent = 'Copied';
      copyStatus.textContent = 'JSON copied to clipboard';
    } catch (error) {
      copyStatus.textContent = 'Copy failed; select the JSON below';
    }
    setTimeout(() => {
      copyButton.textContent = 'Copy JSON';
      copyStatus.textContent = '';
    }, 1800);
  });
  document.querySelector('#previews').append(node);
}

async function loadHarmony(harmony) {
  const status = document.querySelector('#status');
  status.textContent = 'loading…';
  document.querySelector('#previews').replaceChildren();
  try {
    const response = await fetch(`/api/palettes?harmony=${encodeURIComponent(harmony)}`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const items = await response.json();
    items.forEach(render);
    status.textContent = `${items.length} test images · ${harmony} · SOURCE | CALM | MUTE | DEEP | VIBRANT | BALANCED`;
  } catch (error) { status.textContent = error; }
}

const harmonySelect = document.querySelector('#harmony');
harmonySelect.addEventListener('change', () => loadHarmony(harmonySelect.value));
document.querySelector('#copy-all').addEventListener('click', async () => {
  const status = document.querySelector('#copy-all-status');
  try {
    const response = await fetch('/api/palettes/all');
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    await navigator.clipboard.writeText(JSON.stringify(await response.json(), null, 2));
    status.textContent = '72 palettes copied';
  } catch (error) { status.textContent = `Copy failed: ${error}`; }
  setTimeout(() => { status.textContent = ''; }, 2200);
});
loadHarmony(new URLSearchParams(location.search).get('harmony') || 'auto');
