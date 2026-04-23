const pptxgen = require('pptxgenjs');
const html2pptx = require('/home/z/my-project/skills/ppt/scripts/html2pptx');
const path = require('path');

async function main() {
  const pptx = new pptxgen();
  pptx.layout = 'LAYOUT_16x9';

  const slidesDir = '/home/z/my-project/download/ppt-slides';
  const slides = [
    'slide1-cover.html',
    'slide2-toc.html',
    'slide3-ceasefire.html',
    'slide4-talks.html',
    'slide5-straits.html',
    'slide6-outlook.html',
    'slide7-timeline.html',
    'slide8-closing.html',
  ];

  const allWarnings = [];
  for (const file of slides) {
    const filePath = path.join(slidesDir, file);
    console.log(`Processing: ${file}`);
    const { slide, warnings } = await html2pptx(filePath, pptx, {
      fontConfig: { cjk: 'Microsoft YaHei', latin: 'Corbel' }
    });
    allWarnings.push(...warnings.map(w => `${file}: ${w}`));
  }

  if (allWarnings.length > 0) {
    console.log('Warnings:');
    allWarnings.forEach(w => console.log(`  - ${w}`));
  }

  const outputPath = '/home/z/my-project/download/美伊局势最新动态_20260422.pptx';
  await pptx.writeFile({ fileName: outputPath });
  console.log(`PPT saved to: ${outputPath}`);
}

main().catch(err => { console.error(err); process.exit(1); });
