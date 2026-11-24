# [PYTHON] AirGesture - Play games without touching keyboard

## Introduction

Here is my python source code for AirGesture - Play games without touching keyboard. This project is an application of hand detection model in Tensorflow. With my code, you could play many games on PC without using any keyboard. At the moment you could play the following games 
* **Super Mario Bros** by running the **script mario.py**
* **Battle City** by running the script **battle_city.py**
* **Dinosaur Game** by running the script **dinosaur.py**

Please make sure that only one hand shown in front of camera. Otherwise scripts may not work as well as you expect
## Super Mario Bros
The screen is splitted into 3 equal parts horizontally.
Here is the mapping between your gesture and Mario's movement:
- **Open hand within the left part** -> Left jump
- **Closed hand within the left part** -> Left run
- **Open hand within the middle part** -> Jump
- **Closed hand within the middle part** -> Do nothing
- **Open hand within the right part** -> Right jump
- **Closed hand within the right part** -> Right run

<p align="center">
  <img src="demo/Super_mario_bros_demo.gif" width=800><br/>
  <i>Super Mario Bros</i>
</p>

## Battle City
The screen is splitted into 5 parts, including 4 triangles and a circle.
Here is the mapping between your gesture and tank's movement:
- **Open hand** -> Fire
- **Closed hand within the circle** -> Do nothing
- **Closed hand within the left triangle** -> Go left
- **Closed hand within the right triangle** -> Go right
- **Closed hand within the up triangle** -> Go up
- **Closed hand within the left triangle** -> Go down

<p align="center">
  <img src="demo/Battle_city_demo.gif" width=800><br/>
  <i>Battle City</i>
</p>

## Dinosaur Game
The screen is splitted into 2 equal parts vertically.
Here is the mapping between your gesture and dinosaur's action:
- **Closed hand** -> Run
- **Open hand within the upper part** -> Jump
- **Open hand within the lower part** -> Duck

<p align="center">
  <img src="demo/Dinosaur_demo.gif" width=800><br/>
  <i>Dinosaur</i>
</p>

## Requirements

* **python 3.x**
* **cv2**
* **tensorflow** 
* **numpy**
* **gym**
* **gym_super_mario_bros**
* **gym_chrome_dino**
* **pygame**
* **opencv**

---

## GitHub Pages deploy kit (Mesh Avatar Studio + Mesh Avatar Chat)

This branch also contains a ready-to-run GitHub Pages deployment kit adapted
from [`khanhlx6/aituber-onair/.github/workflows`](https://github.com/khanhlx6/aituber-onair/tree/main/.github/workflows):
`.github/workflows/pages.yml` builds a combined site (Mesh Avatar Studio landing
page at `/` and the AITuber OnAir Mesh Avatar Chat demo at `/mesh-avatar-chat/`),
including Miko's pinned piper-plus voice model. See
[`docs/DEPLOY.md`](docs/DEPLOY.md) for the one-command publish steps, the model
URL/hashes, and the local preview command.

If the fork's `prerelease-next` job fails with
`fatal: No names found, cannot describe anything.`, that is because forks do not
inherit git tags. `bash scripts/fix-fork-tags.sh` reports the missing tags and
`APPLY=1 bash scripts/fix-fork-tags.sh` syncs them from upstream (see
[the troubleshooting section](docs/DEPLOY.md#sửa-job-prerelease-next-bị-đỏ-trong-repo-fork)).
