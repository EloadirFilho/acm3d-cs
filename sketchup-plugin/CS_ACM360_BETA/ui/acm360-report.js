/* M8 — Relatório estrutural, lista de corte e plano de barras.
 * Arquivo único usado pelo plugin (ui/studio.html) e pelo painel web (index.html).
 * Funções puras: recebem tubos/bandejas já lidos do modelo e devolvem o relatório,
 * o CSV, o XLSX (bytes) e o HTML de impressão. Testes: tests/acm360-report.test.js
 */
(function (root) {
  'use strict';

  var MAX_CUT_DEG = 75;
  var DENSITY = { aco: 7.85, aluminio: 2.70 }; // g/cm³

  function num(v, d) {
    var n = Number(v);
    return isFinite(n) ? n : (d || 0);
  }

  function round(v, places) {
    var f = Math.pow(10, places == null ? 2 : places);
    return Math.round(num(v) * f) / f;
  }

  function cutLabel(a, b) {
    return round(a, 1) + '°/' + round(b, 1) + '°';
  }

  // Perda extra da serra num corte inclinado: kerf × (1/cos θ − 1), θ limitado a 75°
  function angleLoss(deg, kerf) {
    var a = Math.min(Math.abs(num(deg)), MAX_CUT_DEG);
    if (a < 0.05) return 0;
    return kerf * (1 / Math.cos(a * Math.PI / 180) - 1);
  }

  function isAluminium(material, profile) {
    var m = String(material || '').toLowerCase();
    return (profile && profile.family === 'aluminio') || m.indexOf('alum') === 0;
  }

  // Peso por metro de tubo retangular de parede fina (proposta do plano M8)
  function kgPerMeter(profile, material) {
    if (!profile || !profile.w_mm || !profile.h_mm || !profile.wall_mm) return 0;
    var t = num(profile.wall_mm);
    var areaMm2 = 2 * (num(profile.w_mm) + num(profile.h_mm)) * t - 4 * t * t;
    var dens = isAluminium(material, profile) ? DENSITY.aluminio : DENSITY.aco;
    return areaMm2 * dens / 1000;
  }

  // ---------------------------------------------------------------------------
  // Plano de barras: cada peça ocupa stock + kerf; a barra comporta bar + kerf
  // (o último corte da barra não precisa da serra).
  // ---------------------------------------------------------------------------
  function packFirstFit(pieces, cap) {
    var bars = [];
    pieces.forEach(function (p) {
      for (var i = 0; i < bars.length; i++) {
        if (bars[i].free + 1e-6 >= p.need) { bars[i].pieces.push(p); bars[i].free -= p.need; return; }
      }
      bars.push({ pieces: [p], free: cap - p.need });
    });
    return bars;
  }

  function packBestFit(pieces, cap) {
    var bars = [];
    pieces.forEach(function (p) {
      var best = -1;
      for (var i = 0; i < bars.length; i++) {
        var left = bars[i].free - p.need;
        if (left >= -1e-6 && (best < 0 || left < bars[best].free - p.need)) best = i;
      }
      if (best < 0) bars.push({ pieces: [p], free: cap - p.need });
      else { bars[best].pieces.push(p); bars[best].free -= p.need; }
    });
    return bars;
  }

  // Melhor preenchimento: cada barra recebe o subconjunto que mais a ocupa
  // (subset-sum em mm inteiros, peso arredondado para cima).
  function packSubsetSum(pieces, cap) {
    var left = pieces.slice();
    var capInt = Math.floor(cap);
    var bars = [];
    while (left.length) {
      var w = left.map(function (p) { return Math.ceil(p.need - 1e-6); });
      var from = new Int32Array(capInt + 1).fill(-2); // -2 = inalcançável, -1 = origem
      var prev = new Int32Array(capInt + 1);
      from[0] = -1;
      for (var i = 0; i < left.length; i++) {
        for (var s = capInt - w[i]; s >= 0; s--) {
          if (from[s] !== -2 && from[s + w[i]] === -2) { from[s + w[i]] = i; prev[s + w[i]] = s; }
        }
      }
      var top = capInt;
      while (top > 0 && from[top] === -2) top--;
      var chosen = [];
      for (var c = top; c > 0; c = prev[c]) chosen.push(from[c]);
      if (!chosen.length) chosen = [0];
      chosen.sort(function (a, b) { return b - a; });
      var bar = { pieces: [], free: cap };
      chosen.forEach(function (idx) { var p = left.splice(idx, 1)[0]; bar.pieces.push(p); bar.free -= p.need; });
      bar.pieces.sort(function (a, b) { return b.stock - a.stock; });
      bars.push(bar);
    }
    return bars;
  }

  function maxLeftover(bars) {
    return bars.reduce(function (m, b) { return Math.max(m, b.free); }, 0);
  }

  function planBars(pieces, barMm, kerfMm) {
    var cap = barMm + kerfMm;
    var fits = [];
    var oversize = [];
    pieces.forEach(function (p) {
      var item = { ref: p, stock: p.stock_mm, need: p.stock_mm + kerfMm };
      (p.stock_mm > barMm + 1e-6 ? oversize : fits).push(item);
    });
    fits.sort(function (a, b) { return b.need - a.need; });

    var options = [
      { algo: 'FFD', bars: packFirstFit(fits, cap) },
      { algo: 'Melhor preenchimento', bars: packBestFit(fits, cap) }
    ];
    if (fits.length <= 250) options.push({ algo: 'Melhor preenchimento', bars: packSubsetSum(fits, cap) });
    // Menos barras vence; no empate, a maior sobra (retalho mais aproveitável)
    var best = options.reduce(function (a, b) {
      if (b.bars.length !== a.bars.length) return b.bars.length < a.bars.length ? b : a;
      return maxLeftover(b.bars) > maxLeftover(a.bars) + 1e-6 ? b : a;
    });

    var bars = best.bars.map(function (b) {
      var used = b.pieces.reduce(function (s, p) { return s + p.stock; }, 0);
      return {
        pieces: b.pieces.map(function (p) { return p.ref; }),
        used_mm: round(used, 1),
        leftover_mm: round(Math.max(b.free - kerfMm, 0), 1)
      };
    });
    var oversizeBars = oversize.reduce(function (s, p) { return s + Math.ceil(p.stock / barMm); }, 0);
    return {
      algorithm: fits.length ? best.algo : '-',
      bars: bars,
      oversize: oversize.map(function (p) { return p.ref; }),
      bars_count: bars.length + oversizeBars
    };
  }

  // ---------------------------------------------------------------------------
  // Relatório completo
  // input: { projectName, date, tubes[], trays[], fasteners{} }
  // settings: Configurações M12 normalizadas; profiles: bitolas com price_m
  // ---------------------------------------------------------------------------
  function buildAcmReport(input, settings, profiles) {
    input = input || {};
    settings = settings || {};
    var barMm = num(settings.bar_mm, 6000);
    var kerf = num(settings.kerf_mm, 3);
    var profById = {};
    var profByName = {};
    (profiles || []).forEach(function (p) { profById[String(p.id)] = p; profByName[p.name] = p; });

    var groups = {};
    var order = [];
    (input.tubes || []).forEach(function (t) {
      var len = num(t.length_mm);
      if (len <= 0) return;
      var prof = profById[String(t.profile_id)] || profByName[t.profile_name] || null;
      var wall = num(t.wall_mm, prof ? prof.wall_mm : 0);
      var key = [t.material, t.profile_name, wall].join('|');
      if (!groups[key]) {
        groups[key] = { key: key, material: t.material || '', profile_name: t.profile_name || '', wall_mm: wall, profile: prof, pieces: [] };
        order.push(key);
      }
      var a = num(t.cut_a_deg), b = num(t.cut_b_deg);
      groups[key].pieces.push({
        id: t.id || '', name: t.name || '', frame: t.frame || '',
        length_mm: round(len, 1), cut_a: a, cut_b: b,
        stock_mm: round(len + angleLoss(a, kerf) + angleLoss(b, kerf), 2)
      });
    });

    var warnings = [];
    var cutList = [];
    var profilesOut = order.map(function (key) {
      var g = groups[key];
      var plan = planBars(g.pieces, barMm, kerf);
      plan.oversize.forEach(function (p) {
        warnings.push(g.profile_name + ' · ' + (p.frame ? p.frame + ' · ' : '') + (p.name || p.id) + ': ' +
          p.length_mm + ' mm é maior que a barra de ' + barMm + ' mm e não tem emenda.');
      });

      var lines = {};
      g.pieces.forEach(function (p) {
        var lk = p.length_mm.toFixed(1) + '|' + p.cut_a + '|' + p.cut_b;
        if (!lines[lk]) {
          lines[lk] = { material: g.material, profile_name: g.profile_name, wall_mm: g.wall_mm, length_mm: p.length_mm, cut: cutLabel(p.cut_a, p.cut_b), qty: 0, refs: [] };
        }
        lines[lk].qty += 1;
        lines[lk].refs.push(p.id);
      });
      Object.keys(lines).map(function (k) { return lines[k]; })
        .sort(function (x, y) { return y.length_mm - x.length_mm; })
        .forEach(function (l) {
          l.total_m = round(l.length_mm * l.qty / 1000, 2);
          cutList.push(l);
        });

      var meters = g.pieces.reduce(function (s, p) { return s + p.length_mm; }, 0) / 1000;
      var kgm = kgPerMeter(g.profile || { w_mm: 0 }, g.material);
      var price = g.profile ? num(g.profile.price_m) : 0;
      var boughtM = plan.bars_count * barMm / 1000;
      var used = plan.bars.reduce(function (s, b) { return s + b.used_mm; }, 0);
      return {
        material: g.material,
        profile_name: g.profile_name,
        wall_mm: g.wall_mm,
        pieces: g.pieces.length,
        meters: round(meters, 2),
        bars: plan.bars_count,
        algorithm: plan.algorithm,
        utilization_pct: plan.bars.length ? round(used / (plan.bars.length * barMm) * 100, 1) : 0,
        weight_kg: round(meters * kgm, 1),
        price_m: price,
        cost: price > 0 ? round(boughtM * price, 2) : null,
        plan: plan.bars
      };
    });

    var trays = (input.trays || []).map(function (t) {
      var qty = Math.max(1, Math.round(num(t.quantity, 1)));
      return {
        code: t.code || '', name: t.name || '', qty: qty,
        front_w_mm: round(t.front_w_mm, 1), front_h_mm: round(t.front_h_mm, 1),
        flat_w_mm: round(t.flat_w_mm, 1), flat_h_mm: round(t.flat_h_mm, 1),
        thickness_mm: num(t.thickness_mm), color: t.color || '',
        area_m2: round(num(t.flat_w_mm) * num(t.flat_h_mm) / 1e6 * qty, 3)
      };
    });

    var tapes = settings.tapes || [];
    var tape = tapes.filter(function (x) { return x.id === settings.tape; })[0] || tapes[0] || { name: 'Fita VHB', roll_m: 33, price: 0 };
    var vhb = vhbRequirements(trays, tape);

    var totalCost = profilesOut.reduce(function (s, p) { return s + (p.cost || 0); }, 0) + vhb.cost;
    return {
      project_name: input.projectName || 'Projeto',
      date: input.date || '',
      bar_mm: barMm,
      kerf_mm: kerf,
      profiles: profilesOut,
      cut_list: cutList,
      trays: trays,
      vhb: vhb,
      fasteners: input.fasteners || {},
      warnings: warnings,
      totals: {
        pieces: profilesOut.reduce(function (s, p) { return s + p.pieces; }, 0),
        meters: round(profilesOut.reduce(function (s, p) { return s + p.meters; }, 0), 2),
        bars: profilesOut.reduce(function (s, p) { return s + p.bars; }, 0),
        weight_kg: round(profilesOut.reduce(function (s, p) { return s + p.weight_kg; }, 0), 1),
        acm_m2: round(trays.reduce(function (s, t) { return s + t.area_m2; }, 0), 2),
        trays: trays.reduce(function (s, t) { return s + t.qty; }, 0),
        cost: totalCost > 0 ? round(totalCost, 2) : null
      }
    };
  }

  // Fita no perímetro da face + reforços a cada ~400 mm quando a bandeja passa de 450 mm de altura
  function vhbRequirements(trays, tape) {
    var perim = 0, stiff = 0;
    trays.forEach(function (t) {
      var w = t.front_w_mm, h = t.front_h_mm;
      perim += 2 * (w + h) * t.qty;
      if (h > 450) stiff += Math.max(Math.floor(w / 400) - 1, 0) * (h - 100) * t.qty;
    });
    var meters = (perim + stiff) / 1000;
    var rollM = num(tape.roll_m, 33) || 33;
    var rolls = meters > 0 ? Math.ceil(meters / rollM) : 0;
    return {
      tape_name: tape.name, roll_m: rollM,
      perimeter_m: round(perim / 1000, 2), stiffener_m: round(stiff / 1000, 2),
      meters: round(meters, 2), rolls: rolls,
      primer_cans: meters > 0 ? Math.max(Math.ceil(meters / 100), 1) : 0,
      cost: round(rolls * num(tape.price), 2)
    };
  }

  // ---------------------------------------------------------------------------
  // Tabelas (usadas pelo CSV, XLSX e impressão)
  // ---------------------------------------------------------------------------
  function reportSheets(r) {
    var resumo = [
      ['Projeto', r.project_name], ['Emissão', r.date],
      ['Barra comercial (mm)', r.bar_mm], ['Serra (mm)', r.kerf_mm], [],
      ['Perfil', 'Material', 'Parede (mm)', 'Peças', 'Metros', 'Barras', 'Aproveitamento (%)', 'Peso (kg)', 'R$/m', 'Custo (R$)']
    ];
    r.profiles.forEach(function (p) {
      resumo.push([p.profile_name, p.material, p.wall_mm, p.pieces, p.meters, p.bars, p.utilization_pct, p.weight_kg, p.price_m || '', p.cost == null ? '' : p.cost]);
    });
    resumo.push(['TOTAL', '', '', r.totals.pieces, r.totals.meters, r.totals.bars, '', r.totals.weight_kg, '', r.totals.cost == null ? '' : r.totals.cost]);
    resumo.push([]);
    resumo.push(['ACM (m²)', r.totals.acm_m2], ['Bandejas', r.totals.trays]);
    resumo.push([r.vhb.tape_name + ' (m)', r.vhb.meters], ['Rolos de ' + r.vhb.roll_m + ' m', r.vhb.rolls], ['Primer (frascos 250 ml)', r.vhb.primer_cans]);
    Object.keys(r.fasteners).forEach(function (k) { resumo.push([k, r.fasteners[k]]); });
    r.warnings.forEach(function (w) { resumo.push(['AVISO', w]); });

    var corte = [['Perfil', 'Material', 'Parede (mm)', 'Comprimento (mm)', 'Corte A/B', 'Qtd', 'Total (m)', 'Peças']];
    r.cut_list.forEach(function (l) {
      corte.push([l.profile_name, l.material, l.wall_mm, l.length_mm, l.cut, l.qty, l.total_m, l.refs.join(' ')]);
    });

    var plano = [['Perfil', 'Barra', 'Cortes (mm)', 'Usado (mm)', 'Sobra (mm)']];
    r.profiles.forEach(function (p) {
      p.plan.forEach(function (b, i) {
        plano.push([p.profile_name, i + 1, b.pieces.map(function (x) { return x.length_mm; }).join(' + '), b.used_mm, b.leftover_mm]);
      });
    });

    var acm = [['Código', 'Nome', 'Qtd', 'Face L (mm)', 'Face A (mm)', 'Chapa aberta L (mm)', 'Chapa aberta A (mm)', 'Espessura (mm)', 'Área total (m²)']];
    r.trays.forEach(function (t) {
      acm.push([t.code, t.name, t.qty, t.front_w_mm, t.front_h_mm, t.flat_w_mm, t.flat_h_mm, t.thickness_mm, t.area_m2]);
    });

    return [
      { name: 'Resumo', rows: resumo, widths: [34, 18, 12, 10, 10, 10, 18, 10, 10, 12] },
      { name: 'Lista de Corte', rows: corte, widths: [30, 16, 12, 18, 12, 8, 10, 40] },
      { name: 'Plano de Barras', rows: plano, widths: [30, 8, 60, 12, 12] },
      { name: 'Bandejas ACM', rows: acm, widths: [10, 26, 8, 12, 12, 18, 18, 14, 14] }
    ];
  }

  function reportToCsv(r) {
    return reportSheets(r).map(function (s) {
      return ['--- ' + s.name.toUpperCase() + ' ---'].concat(s.rows.map(function (row) {
        return row.map(function (c) {
          var v = typeof c === 'number' ? String(c).replace('.', ',') : String(c == null ? '' : c);
          return /[;"\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v;
        }).join(';');
      })).join('\r\n');
    }).join('\r\n\r\n') + '\r\n';
  }

  // ---------------------------------------------------------------------------
  // XLSX mínimo (zip sem compressão + SpreadsheetML)
  // ---------------------------------------------------------------------------
  var CRC_TABLE = (function () {
    var t = [];
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c >>> 0;
    }
    return t;
  })();

  function crc32(bytes) {
    var c = 0xFFFFFFFF;
    for (var i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
    return (c ^ 0xFFFFFFFF) >>> 0;
  }

  function utf8(str) {
    return new TextEncoder().encode(str);
  }

  function zipStore(files) {
    var chunks = [], central = [], offset = 0;
    var u16 = function (v) { return [v & 0xFF, (v >>> 8) & 0xFF]; };
    var u32 = function (v) { return [v & 0xFF, (v >>> 8) & 0xFF, (v >>> 16) & 0xFF, (v >>> 24) & 0xFF]; };
    files.forEach(function (f) {
      var name = utf8(f.name), data = utf8(f.data), crc = crc32(data);
      // versão 20, flag UTF-8, sem compressão, data 01/01/1980
      var common = [].concat(u16(20), u16(0x0800), u16(0), u16(0), u16(33), u32(crc), u32(data.length), u32(data.length), u16(name.length), u16(0));
      var local = new Uint8Array([].concat(u32(0x04034b50), common));
      chunks.push(local, name, data);
      central.push(new Uint8Array([].concat(u32(0x02014b50), u16(20), common, u16(0), u16(0), u16(0), u32(0), u32(offset))), name);
      offset += local.length + name.length + data.length;
    });
    var cdSize = central.reduce(function (s, c) { return s + c.length; }, 0);
    var end = new Uint8Array([].concat(u32(0x06054b50), u16(0), u16(0), u16(files.length), u16(files.length), u32(cdSize), u32(offset), u16(0)));
    var all = chunks.concat(central, [end]);
    var out = new Uint8Array(all.reduce(function (s, c) { return s + c.length; }, 0));
    var pos = 0;
    all.forEach(function (c) { out.set(c, pos); pos += c.length; });
    return out;
  }

  function xmlEsc(v) {
    return String(v).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; })
      .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '');
  }

  function colName(i) {
    var s = '';
    for (i += 1; i > 0; i = Math.floor((i - 1) / 26)) s = String.fromCharCode(65 + ((i - 1) % 26)) + s;
    return s;
  }

  function sheetXml(sheet) {
    var header = sheet.name === 'Resumo' ? -1 : 0;
    var rows = sheet.rows.map(function (row, r) {
      var bold = r === header || (sheet.name === 'Resumo' && row[0] === 'Perfil') || row[0] === 'TOTAL';
      var cells = row.map(function (c, ci) {
        if (c === '' || c == null) return '';
        var ref = colName(ci) + (r + 1);
        var s = bold ? ' s="1"' : '';
        if (typeof c === 'number' && isFinite(c)) return '<c r="' + ref + '"' + s + '><v>' + c + '</v></c>';
        return '<c r="' + ref + '"' + s + ' t="inlineStr"><is><t xml:space="preserve">' + xmlEsc(c) + '</t></is></c>';
      }).join('');
      return '<row r="' + (r + 1) + '">' + cells + '</row>';
    }).join('');
    var cols = (sheet.widths || []).map(function (w, i) {
      return '<col min="' + (i + 1) + '" max="' + (i + 1) + '" width="' + w + '" customWidth="1"/>';
    }).join('');
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
      (cols ? '<cols>' + cols + '</cols>' : '') + '<sheetData>' + rows + '</sheetData></worksheet>';
  }

  function reportToXlsx(r) {
    var sheets = reportSheets(r);
    var ns = 'http://schemas.openxmlformats.org/';
    var files = [
      { name: '[Content_Types].xml', data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Types xmlns="' + ns + 'package/2006/content-types">' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
        '<Default Extension="xml" ContentType="application/xml"/>' +
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
        sheets.map(function (s, i) {
          return '<Override PartName="/xl/worksheets/sheet' + (i + 1) + '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>';
        }).join('') + '</Types>' },
      { name: '_rels/.rels', data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="' + ns + 'package/2006/relationships">' +
        '<Relationship Id="rId1" Type="' + ns + 'officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>' },
      { name: 'xl/workbook.xml', data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<workbook xmlns="' + ns + 'spreadsheetml/2006/main" xmlns:r="' + ns + 'officeDocument/2006/relationships"><sheets>' +
        sheets.map(function (s, i) {
          return '<sheet name="' + xmlEsc(s.name) + '" sheetId="' + (i + 1) + '" r:id="rId' + (i + 1) + '"/>';
        }).join('') + '</sheets></workbook>' },
      { name: 'xl/_rels/workbook.xml.rels', data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="' + ns + 'package/2006/relationships">' +
        sheets.map(function (s, i) {
          return '<Relationship Id="rId' + (i + 1) + '" Type="' + ns + 'officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' + (i + 1) + '.xml"/>';
        }).join('') +
        '<Relationship Id="rId' + (sheets.length + 1) + '" Type="' + ns + 'officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>' },
      { name: 'xl/styles.xml', data: '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<styleSheet xmlns="' + ns + 'spreadsheetml/2006/main">' +
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>' +
        '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>' +
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
        '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>' +
        '</styleSheet>' }
    ];
    sheets.forEach(function (s, i) { files.push({ name: 'xl/worksheets/sheet' + (i + 1) + '.xml', data: sheetXml(s) }); });
    return zipStore(files);
  }

  function bytesToBase64(bytes) {
    var bin = '';
    for (var i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    return typeof btoa === 'function' ? btoa(bin) : Buffer.from(bin, 'binary').toString('base64');
  }

  // ---------------------------------------------------------------------------
  // HTML para impressão (cabeçalho da empresa vem das Configurações)
  // ---------------------------------------------------------------------------
  function reportToHtml(r, settings) {
    settings = settings || {};
    var esc = function (v) { return xmlEsc(v == null ? '' : v); };
    var fmt = function (v) { return typeof v === 'number' ? String(v).replace('.', ',') : esc(v); };
    var table = function (s) {
      var rows = s.rows.filter(function (row) { return row.length; });
      var head = s.name === 'Resumo' ? rows.filter(function (row) { return row[0] === 'Perfil'; })[0] : rows[0];
      var body = s.name === 'Resumo'
        ? rows.slice(rows.indexOf(head) + 1).filter(function (row) { return row.length > 2; })
        : rows.slice(1);
      if (!body.length) return '';
      return '<h2>' + esc(s.name) + '</h2><table><thead><tr>' + head.map(function (h) { return '<th>' + esc(h) + '</th>'; }).join('') +
        '</tr></thead><tbody>' + body.map(function (row) {
          return '<tr' + (row[0] === 'TOTAL' ? ' class="total"' : '') + '>' + row.map(function (c) { return '<td>' + fmt(c) + '</td>'; }).join('') + '</tr>';
        }).join('') + '</tbody></table>';
    };
    var sheets = reportSheets(r);
    var extras = [
      ['ACM', r.totals.acm_m2 + ' m² · ' + r.totals.trays + ' bandeja(s)'],
      [r.vhb.tape_name, r.vhb.meters + ' m · ' + r.vhb.rolls + ' rolo(s) de ' + r.vhb.roll_m + ' m · primer: ' + r.vhb.primer_cans + ' frasco(s)']
    ];
    Object.keys(r.fasteners).forEach(function (k) { extras.push([k, r.fasteners[k] + ' un']); });
    var logo = settings.company_logo ? '<img src="' + esc(settings.company_logo) + '" alt="">' : '';
    return '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Relatório · ' + esc(r.project_name) + '</title><style>' +
      'body{font:12px/1.4 Arial,sans-serif;color:#111;margin:16px}header{display:flex;gap:16px;align-items:center;border-bottom:2px solid #111;padding-bottom:8px}' +
      'header img{max-height:56px}h1{font-size:18px;margin:0}h2{font-size:14px;margin:18px 0 6px}table{border-collapse:collapse;width:100%}' +
      'th,td{border:1px solid #999;padding:3px 6px;text-align:left}th{background:#eee}tr.total td{font-weight:bold}' +
      '.warn{border:1px solid #c00;color:#900;padding:6px;margin-top:10px}@media print{h2{break-after:avoid}tr{break-inside:avoid}}' +
      '</style></head><body><header>' + logo + '<div><h1>' + esc(settings.company_name || 'Relatório de Produção') + '</h1><div>' +
      esc([settings.company_phone, settings.company_email].filter(Boolean).join(' · ')) + '</div></div></header>' +
      '<p><b>Projeto:</b> ' + esc(r.project_name) + ' · <b>Emissão:</b> ' + esc(r.date) + ' · <b>Barra:</b> ' + r.bar_mm + ' mm · <b>Serra:</b> ' + fmt(r.kerf_mm) + ' mm</p>' +
      (r.warnings.length ? '<div class="warn">' + r.warnings.map(esc).join('<br>') + '</div>' : '') +
      sheets.map(table).join('') +
      '<h2>Materiais de colagem e fixação</h2><table><tbody>' + extras.map(function (e) { return '<tr><th>' + esc(e[0]) + '</th><td>' + esc(e[1]) + '</td></tr>'; }).join('') + '</tbody></table>' +
      '<script>window.onload=function(){window.print();};<\/script></body></html>';
  }

  var api = {
    buildAcmReport: buildAcmReport,
    planBars: planBars,
    kgPerMeter: kgPerMeter,
    reportSheets: reportSheets,
    reportToCsv: reportToCsv,
    reportToXlsx: reportToXlsx,
    reportToHtml: reportToHtml,
    bytesToBase64: bytesToBase64
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.AcmReport = api;
})(typeof window !== 'undefined' ? window : this);
