import { chromium } from 'playwright';

const browser = await chromium.launchPersistentContext('/home/brosso3d/.chrome-teams', {
  headless: true,
  executablePath: '/usr/bin/google-chrome-stable',
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
});

const page = browser.pages()[0] || await browser.newPage();

const chats = [
  { nombre: 'Web Devs (Devs Only)', url: 'https://teams.microsoft.com/l/chat/19:0f70fa92047442b0ae589e7778c3691a@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D' },
  { nombre: 'Scrum Team Chat',      url: 'https://teams.microsoft.com/l/chat/19:6975d3242b3040929cd4aa928313c306@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D' },
  { nombre: '#TheFantastic4',        url: 'https://teams.microsoft.com/l/chat/19:4b5d3aa3e6c046abaeaf0622bf55f034@thread.v2/conversations?context=%7B%22contextType%22%3A%22chat%22%7D' },
];

for (const { nombre, url } of chats) {
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(5000);

  const currentUrl = page.url();
  if (currentUrl.includes('login') || currentUrl.includes('oauth')) {
    console.log(`\n[${nombre}] Sesión expirada — necesita re-login`);
    continue;
  }

  const lines = await page.evaluate(() => {
    const all = document.body.innerText.split('\n').map(l => l.trim()).filter(l => l.length > 3);
    const start = all.findIndex(l => l === 'Message List');
    return start >= 0 ? all.slice(start + 1, start + 60) : all.slice(-60);
  });

  console.log(`\n===== ${nombre} =====`);
  lines.forEach(l => console.log(l));
}

await browser.close();
