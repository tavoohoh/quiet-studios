// Usage: node dc2static.js <in.dc.html> <out.html> <marker line>   (props: PROPS='{"showSafe":false}')
// Renders a Design Component to static HTML: holes, nested <sc-if>/<sc-for> and <dc-import>
// (imported artboards are read from the same folder, recursively).
const fs = require('fs');
const path = require('path');
const [, , inPath, outPath, marker] = process.argv;
const dir = path.dirname(inPath);
const board = path.basename(inPath);
const helmets = new Set();
const cache = {};

function load(name) {
  if (cache[name]) return cache[name];
  const src = fs.readFileSync(path.join(dir, name), 'utf8');
  const script = /<script type="text\/x-dc"[^>]*data-props='([^']*)'[^>]*>([\s\S]*?)<\/script>/.exec(src)
    || /<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/.exec(src);
  const propsDef = script.length === 3 ? JSON.parse(script[1]) : {};
  const code = script.length === 3 ? script[2] : script[1];
  class DCLogic { constructor(props) { this.props = props; } }
  const Component = new Function('DCLogic', code + '\nreturn Component;')(DCLogic);
  const helmet = (/<helmet>([\s\S]*?)<\/helmet>/.exec(src) || ['', ''])[1];
  const body = /<x-dc>([\s\S]*?)<\/x-dc>/.exec(src)[1].replace(/<helmet>[\s\S]*?<\/helmet>/, '');
  return (cache[name] = { propsDef, Component, helmet, body });
}

const get = (p, scope) => {
  if (p === 'true') return true;
  if (p === 'false') return false;
  return p.split('.').reduce((o, k) => (o == null ? o : o[k]), scope);
};
const fill = (text, scope) => text.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (_, p) => { const v = get(p, scope); return v == null ? '' : String(v); });
const attrs = (tag) => { const a = {}; tag.replace(/([\w-]+)="([^"]*)"/g, (_, k, v) => { a[k] = v; }); return a; };

// Finds the closing tag that matches the opener at `start`, counting nested openers of the same tag.
function matchClose(text, start, tag) {
  const open = new RegExp(`<${tag}[\\s>]|</${tag}>`, 'g');
  open.lastIndex = start;
  let depth = 0, m;
  while ((m = open.exec(text))) {
    if (m[0].startsWith('</')) { depth--; if (depth === 0) return m.index; }
    else depth++;
  }
  throw new Error('unclosed ' + tag);
}

function render(text, scope) {
  let out = '';
  let i = 0;
  const re = /<(sc-if|sc-for|dc-import)\b[^>]*>/g;
  let m;
  while ((re.lastIndex = i, m = re.exec(text))) {
    out += fill(text.slice(i, m.index), scope);
    const tag = m[1];
    const close = matchClose(text, m.index, tag);
    const inner = text.slice(m.index + m[0].length, close);
    const a = attrs(m[0]);
    if (tag === 'sc-if') {
      const v = get(/\{\{\s*([\w.]+)\s*\}\}/.exec(a.value)[1], scope);
      if (v) out += render(inner, scope);
    } else if (tag === 'sc-for') {
      const list = get(/\{\{\s*([\w.]+)\s*\}\}/.exec(a.list)[1], scope) || [];
      for (const item of list) out += render(inner, { ...scope, [a.as]: item });
    } else {
      const props = {};
      for (const [k, v] of Object.entries(a)) {
        if (k === 'name' || k.startsWith('hint-')) continue;
        const val = fill(v, scope);
        props[k] = (k === 'w' || k === 'h') && /^-?\d+(\.\d+)?$/.test(val) ? Number(val) : val;
      }
      const [w, h] = fill(a['hint-size'] || '', scope).split(',');
      const box = w ? `<div style="width: ${w}; height: ${h}; position: relative">` : '<div>';
      out += box + component(a.name + '.dc.html', props) + '</div>';
    }
    i = close + `</${tag}>`.length;
  }
  return out + fill(text.slice(i), scope);
}

function component(name, given) {
  const c = load(name);
  helmets.add(c.helmet.trim());
  const props = { ...given };
  for (const [k, d] of Object.entries(c.propsDef)) if (!k.startsWith('$') && props[k] === undefined && d && 'default' in d) props[k] = d.default;
  const vals = new c.Component(props).renderVals() || {};
  return render(c.body, vals).trim();
}

const body = component(board, JSON.parse(process.env.PROPS || '{}')).replace(/ href="[A-Za-z]+\.dc\.html"/g, ' href="#"');
// One <style>body{margin:0}</style> is enough; keep every font link once.
const head = [...new Set([...helmets].join('\n').split('\n').map(l => l.trim()).filter(Boolean))].join('\n');
fs.writeFileSync(outPath, `${marker}
<!doctype html>
<html>
<head>
<meta charset="utf-8">
${head}
</head>
<body>
${body}
<script>/* static snapshot of the canvas artboard */</script>
</body>
</html>
`);
