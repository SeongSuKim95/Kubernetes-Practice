# 장별 썸네일

2026-10-19 기준 검토 및 생성 결과입니다.

| 장 | 사용 파일 | 썸네일 제목 | 검토 결과 |
|---|---|---|---|
| 3 | `week03-thumbnail.png` | Chap03. Pod와 Deployment | 본문 핵심 제목과 일치, 글자 잘림과 겹침 없음 |
| 4 | `week04-thumbnail-v2.png` | Chap04. Pod의 실행과 상태 확인 | 이전 제목의 자동 복구 내용을 제거한 수정본 |
| 5 | `week05-thumbnail.png` | Chap05. Pod의 장애와 자동 복구 | 본문의 부제는 생략하고 핵심 제목을 사용한 신규 이미지 |
| 6 | `week06-thumbnail.png` | Chap06. Service와 클러스터 통신 | 본문 핵심 제목과 일치, 글자 잘림과 겹침 없음 |
| 7 | `week07-thumbnail.png` | Chap07. Service와 Ingress: HTTP 라우팅과 HTTPS | 본문 제목과 일치, 글자 잘림과 겹침 없음 |

기존 `week04-thumbnail.png`는 이전 버전입니다. 현재 4장에는 v2 파일을 사용합니다.

## 생성 방식과 프롬프트

4장 수정본과 5장 신규 이미지는 내장 imagegen 도구로 생성했습니다. 기존 파일은 덮어쓰지 않았습니다.

4장 참조: `week04-thumbnail.png`

> Edit this existing Korean Kubernetes series thumbnail. Preserve the entire background, official Kubernetes logo, composition, colors, dimensions/aspect ratio, main Kubernetes word, and Korean top line exactly. Change ONLY the chapter subtitle from the old text to this exact text: "Chap04. Pod의 실행과 상태 확인". Match existing white lettering black outline and alignment, single line, no overflow or overlap. Do not add anything else. This is a precise title correction for chapter 4, not a new design.

5장 참조: `week03-thumbnail.png`

> Create the chapter 5 thumbnail by editing this reference thumbnail from the same series. Preserve the reference background, Kubernetes official logo, layout, colors, aspect ratio, Korean top line "성수 선임과 함께 배우는", and large word "Kubernetes" exactly. Replace ONLY the chapter subtitle with the exact single line "Chap05. Pod의 장애와 자동 복구". Match the existing white text with crisp black outline, placement below Kubernetes, and generous right margin. Keep everything readable at thumbnail size, no text overlap, no new illustrations or elements. Use the same image dimensions as the reference.

6장 참조: `week05-thumbnail.png`

> Create the chapter 6 thumbnail by editing this reference thumbnail from the same series. Preserve the reference background, Kubernetes official logo, layout, colors, aspect ratio, Korean top line "성수 선임과 함께 배우는", and large word "Kubernetes" exactly. Replace ONLY the chapter subtitle with the exact single line "Chap06. Service와 클러스터 통신". Match the existing white text with crisp black outline, placement below Kubernetes, and generous right margin. Keep everything readable at thumbnail size, no text overlap, no new illustrations or elements. Use the same image dimensions as the reference.
