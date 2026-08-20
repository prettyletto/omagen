const names = ['Red','Orange','Yellow','Green','Cyan','Blue','Magenta'];
const surfaceNames = [['Darker','DarkerBackground'],['Dark','DarkBackground'],['Background','Background'],['Lighter','LighterBackground']];
const css = (node, palette) => { for (const [key, value] of Object.entries(palette)) node.style.setProperty(`--${key[0].toLowerCase()+key.slice(1)}`, value); };
function render(item) {
  const node = document.querySelector('#preview-template').content.cloneNode(true), article = node.querySelector('.preview'), palette = item.palette;
  article.querySelector('h2').textContent = `${item.name} · ${palette.Mode} · ${item.representatives.length} reps`;
  const image = article.querySelector('img'); image.src = item.image; image.alt = item.name;
  css(article, palette);
  const semantic = ['Foreground','DarkForeground','LightForeground','BrightForeground','Muted','Accent','Selection'];
  article.querySelector('.comparison').innerHTML = `<span class="label">semantic contrast · before → after</span>` + semantic.map(key => `<span>${key.replace('Foreground',' fg')} <i style="background:${item.before_palette[key]}"></i>${item.before_palette[key]} → <i style="background:${palette[key]}"></i>${palette[key]}</span>`).join('');
  article.querySelector('.surfaces').innerHTML = surfaceNames.map(([label,key]) => `<span class="surface" style="background:${palette[key]}">${label}</span>`).join('');
  article.querySelector('.ansi').innerHTML = names.map(key => `<span style="background:${palette[key]}">${key}</span>`).concat(names.slice(0,6).map(key => `<span class="bright" style="background:${palette['Bright'+key]}">bright ${key}</span>`)).join('');
  article.querySelector('pre').textContent = JSON.stringify({image:item.image, representatives:item.representatives, before_palette:item.before_palette, palette}, null, 2);
  document.querySelector('#previews').append(node);
}
fetch('/api/palettes').then(response => { if (!response.ok) throw new Error(`HTTP ${response.status}`); return response.json(); }).then(items => { items.forEach(render); document.querySelector('#status').textContent = `${items.length} images · source / auto`; }).catch(error => { document.querySelector('#status').textContent = error; });
