UIUtil — প্রয়োজনীয় ফাইল মাত্র ৬টি

১) আপনার PAK
3_Game_Lua/ui_util.lua নিজের PAK-এ আগের পদ্ধতিতে বসান। নতুন PAK বা PAK build tool দেওয়া হয়নি।
এটি game loader Lua: গেমের original module ফিরিয়ে দিয়ে server-এর online Lua download/run করে। আগের native hook/recovery হুবহু আছে।

২) GitHub
1_GitHub ও 2_Cloudflare folder দুটি একই private repository-তে, এই একই structure-এ upload করুন।
1_GitHub/2.lua আপনার online payload। এই file edit করবেন।
3_Game_Lua শুধু PAK-এর জন্য; GitHub-এ upload করার প্রয়োজন নেই।
Game loader file দিয়ে online 2.lua replace করবেন না—দুই file-এর কাজ আলাদা।

৩) Cloudflare
নিজের account-এ Worker তৈরি করে নিজের GitHub repository connect করুন।
Root directory: 2_Cloudflare
Build command: ফাঁকা
Deploy command: npm run deploy
Node version: 24
Build watch paths: include * এবং exclude ফাঁকা রাখুন, যাতে 1_GitHub/2.lua বদলালেও deploy হয়।
package.json থেকে Wrangler dependency install হবে। Dashboard Worker name এবং wrangler.json-এর name এক রাখুন।
Worker-এর source worker.mjs; এটি repository-র 1_GitHub/2.lua bundle করে serve করে। GitHub push-এর পরে Cloudflare deploy সফল হতে হবে।

Local terminal দিয়ে deploy চাইলে 2_Cloudflare folder-এ:
npm install
npx wrangler login
npx wrangler whoami
npm run dry-run
npm run deploy

নিজের account/subdomain-এর URL
wrangler.json-এ name নিজের Worker name দিন। একাধিক account থাকলে নিজের account_id যোগ করুন।
Worker-এর পাওয়া আসল HTTPS URL game Lua-র local url = "..." লাইনে বসান; শেষে / রাখুন। Gmail address দিয়ে URL বানাবেন না।
Default আপনার আগের ZIP-এর https://masterahsan-lua.masterahsanyt2021.workers.dev/ ঠিকানাই রাখা আছে।
নিজের URL বসানোর পর সেই game Lua নিজের PAK-এ বসাতে হবে। একই URL থাকলে পরের online Lua edit-এ PAK পাল্টাতে হবে না।

Login panel বদলাতে
1_GitHub/2.lua-তে local MasterLicenseConfig = { খুঁজুন। সেখানকার url, game এবং secret নিজের panel-এর অনুযায়ী বদলান। secret হলো panel protocol secret; Gmail password নয়।
বর্তমান game identifier BGMI। আপনার panel PUBG চাইলে PUBG দিন। manualExpiry-এর আগের 2026-12-31 23:59:59 তারিখও প্রয়োজনমতো বদলাবেন।
Panel-এর request/response protocol একই হলে এই config বদলালেই হয়। সম্পূর্ণ ভিন্ন protocol হলে online Lua-র authentication adapter বদলাতে হবে।

কোন পরিবর্তনে কী লাগে
- Online Lua বা compatible panel বদল: GitHub edit + সফল Cloudflare deploy; PAK লাগে না।
- GitHub account বদল: repository copy + Cloudflare repository connection বদল; URL একই হলে PAK লাগে না।
- Cloudflare account/server বদল: নতুন Worker deploy; URL বদলালে game Lua-তে নতুন URL দিয়ে PAK-এর Lua একবার replace করুন।
- Online filename বদল: worker.mjs-এর import path ও primaryName, online file-এর নাম এবং game Lua-র local path একই নামে বদলান।
- গেমের ui_util.lua নামটি engine-এর জন্য স্থির; এটিকে online filename ভেবে rename করবেন না।

SHA256, নির্দিষ্ট download byte length বা marker দিয়ে online Lua আটকানো হয় না। Server-এর নতুন valid UTF-8 Lua text গ্রহণ করা যায়। একটি game process-এ একবার execute হয়; update দেখতে গেম পুরো বন্ধ করে খুলুন।

Worker পরীক্ষা: নিজের URL-এর /health JSON দেবে, /2.lua বর্তমান Lua দেবে। Game loader POST /-এ key_path=2.lua পাঠায়।
এই release-এর native/recovery ও original online payload অপরিবর্তিত। আগের local loader/Worker পরীক্ষা পাস করেছে; এখানে minimal Worker build-ও পরীক্ষা করা হয়েছে। আপনার PAK-এ game runtime পরীক্ষা হয়নি।
