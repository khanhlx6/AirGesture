# Deploy Mesh Avatar Studio + Mesh Avatar Chat lên GitHub Pages

Bộ này dùng workflow `.github/workflows/pages.yml` (được chuyển thể từ
[`khanhlx6/aituber-onair/.github/workflows/pages.yml`](https://github.com/khanhlx6/aituber-onair/tree/main/.github/workflows)
và `shinshin86/mesh-avatar-studio/.github/workflows/pages.yml`) để dựng **một
trang duy nhất** gồm:

| Đường dẫn | Nội dung |
| --- | --- |
| `/` | Landing page **Mesh Avatar Studio** (có thêm thẻ liên kết tới demo) |
| `/mesh-avatar-chat/` | Demo **AITuber OnAir – Mesh Avatar Chat** (Miko: avatar, khẩu hình, cảm xúc, giọng nói) |

Khi đặt vào repo `khanhlx6/aituber-onair`, URL sẽ là:

- <https://khanhlx6.github.io/aituber-onair/>
- <https://khanhlx6.github.io/aituber-onair/mesh-avatar-chat/>

> **Lưu ý về URL bạn gửi:** `https://khanhlegood12.github.io/mesh-avatar-studio/`
> (trong câu hỏi có ghi `khanhlegood6`, và link hiển thị
> `shinshin86.github.io/mesh-avatar-studio/`) thuộc **tài khoản/repo khác**.
> Hiện trang đó trả về 404 vì chưa có bản deploy. Token GitHub của phiên làm
> việc này chỉ có quyền ghi vào `khanhlx6/AirGesture`; nó **không có quyền**
> push, bật Pages hay chạy Actions trên `khanhlx6/aituber-onair` và
> `khanhlegood12/mesh-avatar-studio` (kiểm tra bằng API: 403 / 404). Vì vậy mình
> chuẩn bị sẵn toàn bộ deploy kit + 2 cách chạy 1 lệnh ở dưới; bạn chỉ cần chạy
> bằng tài khoản có quyền trên repo đích. Nếu vẫn muốn đích là
> `khanhlegood12/mesh-avatar-studio`, đặt `TARGET_REPO=khanhlegood12/mesh-avatar-studio`.

---

## 1. Cách nhanh nhất (chạy trên máy của bạn)

```bash
cd AirGesture
bash scripts/deploy-to-fork.sh
# hoặc chỉ định repo khác:
# TARGET_REPO=khanhlegood12/mesh-avatar-studio bash scripts/deploy-to-fork.sh
```

Yêu cầu: đã `gh auth login` bằng tài khoản có quyền **push** lên repo đích
(hoặc đặt biến `PAGES_DEPLOY_TOKEN`). Script sẽ:

1. clone repo đích,
2. copy `.github/workflows/pages.yml`, `scripts/build-site.sh`,
   `scripts/verify-piper-assets.sh`, `docs/DEPLOY.md` và nối thêm
   `/build/` vào `.gitignore` của repo đích,
3. bật **Settings → Pages → Source: GitHub Actions** qua API,
4. commit + push lên `main`,
5. `gh workflow run pages.yml` để deploy ngay.

## 2. Cách chạy từ GitHub Actions của repo này

1. Tạo PAT (classic, scope `repo`) hoặc fine-grained token có
   `Contents: write`, `Pages: write`, `Actions: write`, `Administration: write`
   trên repo đích.
2. Thêm secret `PAGES_DEPLOY_TOKEN` vào `khanhlx6/AirGesture`.
3. Vào **Actions → Publish Pages deploy kit to aituber-onair fork → Run workflow**
   (có thể đổi `target_repo`).

Workflow này làm đúng các bước như script ở mục 1, nhưng chạy trên runner của
GitHub. Repo đích sau đó tự deploy bằng `pages.yml` của chính nó.

## 3. Cách thủ công

Copy 4 file sau vào repo đích (giữ nguyên đường dẫn), bật Pages ở chế độ
**GitHub Actions**, rồi push lên `main`:

```
.github/workflows/pages.yml
scripts/build-site.sh
scripts/verify-piper-assets.sh
docs/DEPLOY.md
```

Nhớ thêm dòng `/build/` vào `.gitignore` của repo đích.

Nếu Pages chưa được bật và bạn không muốn dùng PAT, bật tay một lần:
**Settings → Pages → Build and deployment → Source = GitHub Actions**.
(Trong `pages.yml` có sẵn `configure-pages` với `enablement` tự động khi có
secret `PAGES_DEPLOY_TOKEN`; `GITHUB_TOKEN` thông thường không đủ quyền bật
Pages lần đầu.)

---

## Workflow làm những gì

`scripts/build-site.sh` chạy trên `ubuntu-latest` với Node 22:

1. Tải source `khanhlx6/aituber-onair@main` và
   `shinshin86/mesh-avatar-studio@main` (codeload tarball) — **không commit
   artifact build vào Git**.
2. Build workspace AITuber (`chat`, `voice`, `core`) rồi build
   `demo/mesh-avatar-chat` với `VITE_BASE_PATH=/<repo>/mesh-avatar-chat/`
   (đúng như `pages.yml` gốc).
3. Tải piper-plus runtime/OpenJTalk dictionary từ GitHub Release
   `shinshin86/chrome-on-aituber@piper-assets-v2`, và giọng Miko từ URL mặc
   định ở dưới; kiểm tra SHA‑256.
4. Build landing page studio với `base` và `publishedUrl` được patch theo repo
   đích (canonical/OG URL cũng được đổi), rồi chèn thẻ "Talk to Miko" trỏ tới
   `./mesh-avatar-chat/`.
5. Ghép `/` + `/mesh-avatar-chat/` + `404.html`, upload bằng
   `actions/upload-pages-artifact@v3` và deploy bằng `actions/deploy-pages@v4`.

### Nguồn giọng Miko (đã tìm trong tài khoản `shinshin86`)

File `shinshin86/chrome-on-aituber/scripts/piper/fetch-miko-voice.sh` chứa
đường dẫn và hash của model:

| Thành phần | Giá trị |
| --- | --- |
| Model | `sample-voice-v2.onnx` (~38 MB) + `sample-voice-v2.onnx.json` |
| Host | `https://huggingface.co/shinshin86/aituber-onair-miko-voice-piper-plus` |
| Revision | `b7db1788bcab3ccaec6d3b541ba6195edab48e1f` |
| `PIPER_MODEL_BASE_URL` | `https://huggingface.co/shinshin86/aituber-onair-miko-voice-piper-plus/resolve/b7db1788bcab3ccaec6d3b541ba6195edab48e1f` |
| SHA‑256 model | `20155a363e0a80ed425415d73c58c6f7559407b2ddca675811379719b45e5995` |
| SHA‑256 config | `f1102d8a355d23c835b4f74316ea9f86455fbbeb8fc551681c012407c4f79002` |

Bạn có thể override bằng repository variable `PIPER_MODEL_BASE_URL` và
`PIPER_ASSETS_URL`. Nếu chạy `workflow_dispatch` với `skip_piper=true` (hoặc
`SKIP_PIPER=1` khi build local), demo vẫn chạy với giọng **Web Speech API** và
ẩn tuỳ chọn giọng Miko — tiết kiệm ~150 MB.

> Bản quyền: Miko © Yuki Shindo (AITuber OnAir), model giọng được fine-tune từ
> piper-plus `zs-v1` (MIT). Các notice nằm trong
> `demo/mesh-avatar-chat/licenses/` của repo nguồn.

---

## Xem thử trên máy (không cần deploy)

```bash
cd AirGesture
SITE_BASE=/ SKIP_PIPER=1 bash scripts/build-site.sh
python3 -m http.server 8000 --directory build/site
# mở http://localhost:8000/  và  http://localhost:8000/mesh-avatar-chat/
```

`build/` đã được đưa vào `.gitignore`. Nếu muốn build lại không tải mạng:

```bash
AITUBER_SOURCE=/path/to/aituber-onair \
STUDIO_SOURCE=/path/to/mesh-avatar-studio \
SITE_BASE=/ SKIP_PIPER=1 bash scripts/build-site.sh
```

## Các workflow gốc trong `khanhlx6/aituber-onair/.github/workflows`

`pages.yml` là workflow duy nhất được dùng trực tiếp (chuyển thể). Các file còn
lại (`ci.yml`, `release.yml`, `prerelease-next.yml`, `create-template-smoke.yml`,
`biome-config.yml`, `chat-openai-compat.yml`,
`agent-stream-operations-staff.yml`) là CI/publishing của chính monorepo
TypeScript đó, nên không copy sang đây để tránh chạy nhầm trên repo Python này.

## Sửa job `prerelease-next` bị đỏ trong repo fork

Trong repo fork `khanhlx6/aituber-onair`, job **prerelease-next** hay fail với:

```
fatal: No names found, cannot describe anything.
Error: Process completed with exit code 128.
```

**Nguyên nhân:** GitHub **không copy git tag** khi bạn fork một repository, nên
fork bắt đầu với `0` tag (repo gốc `shinshin86/aituber-onair` có 246 tag). Bước
đầu tiên của `.github/workflows/prerelease-next.yml` là:

```bash
last_tag=$(git describe --tags --abbrev=0 \
           $(git rev-list --tags --no-walk --exclude='next' --exclude='*-rc*' --max-count=1))
```

Khi fork không có tag nào, `git rev-list --tags` không in ra gì, nên
`git describe --tags --abbrev=0` được gọi **không có tham số** → fail với exit
code 128. Lỗi này **không ảnh hưởng** tới bước deploy Pages (job
*Deploy demo to GitHub Pages* vẫn xanh), nó chỉ làm tab Actions có dấu đỏ.

**Cách sửa (khuyên dùng): đồng bộ tag từ upstream vào fork**

```bash
# xem trước sẽ push những tag nào (không thay đổi gì)
bash scripts/fix-fork-tags.sh

# push thật (cần token có quyền contents:write trên khanhlx6/aituber-onair)
APPLY=1 bash scripts/fix-fork-tags.sh

# fork khác thì đổi target:
APPLY=1 FORK_REPO=owner/repo bash scripts/fix-fork-tags.sh
```

Script sẽ fetch toàn bộ tag của `shinshin86/aituber-onair` rồi chỉ push những tag
fork còn thiếu (bỏ qua tag `next` vì đó là tag "nightly" di động do chính workflow
quản lý; muốn copy luôn thì đặt `INCLUDE_NIGHTLY=1`). Script chạy lại nhiều lần
vẫn an toàn (idempotent) và không sửa file nào trong fork — nên việc merge
`shinshin86:main` vào `main` sau này không bị conflict.

Sau đó chạy lại job đã fail:

```bash
gh run rerun 45405131269 -R khanhlx6/aituber-onair
```

**Cách khác: tắt hẳn workflow nightly trong fork** (nếu bạn không cần bản
prerelease `next` cho fork của mình)

```bash
# cần token có quyền actions:write (PAT của bạn, không phải GITHUB_TOKEN)
gh api -X PUT repos/khanhlx6/aituber-onair/actions/workflows/prerelease-next.yml/disable
# bật lại:
gh api -X PUT repos/khanhlx6/aituber-onair/actions/workflows/prerelease-next.yml/enable
```

Hoặc vào **Settings → Actions → General** / tab **Actions** → chọn
`prerelease-next` → **Disable workflow** (không cần token). Cách này giữ fork
sạch tuyệt đối nhưng bạn sẽ không có nightly prerelease.

> Ghi chú: token tích hợp của Arena hiện chỉ đọc được metadata của
> `khanhlx6/aituber-onair` (mọi lệnh ghi như `git push`, sửa file, `PUT /actions/...`
> đều trả 403), nên hai lệnh trên cần chạy bằng `gh`/PAT của chính bạn.
