# Service와 Deployment의 Label 연결 삽화

## 최종 구성 재설계

기본 image_gen 도구로 문 형태의 기존 배치를 제거하고, 클라이언트의 접근 관계와 두 Deployment의 Pod 관리 관계를 중심으로 재배치했습니다. 결과는 interaction-service-deployment-labels.png에 반영했습니다.

Completely redesign the composition of this Kubernetes teaching illustration, using the reference ONLY for recognizable character designs, emblems, glossy cute 3D style and Label symbols. Do NOT preserve old layout. REMOVE the large green arch entirely. New balanced landscape composition with clear conceptual hierarchy, not a lineup: upper-left a purple client Pod offers a cyan-diamond-sealed envelope toward a lime-green Service guide at center-left. Service holds a cyan diamond selector sample and gestures toward TWO cyan-diamond-banded purple receiver Pods at lower-center/right; receivers face the sender and extend welcoming hands. Behind and ABOVE these two receiver Pods stands their orange hardhat Deployment supervisor, clipboard with cyan diamond, actively attaching/checking one Pod's cyan Label. Separately on the far right, slightly farther back and with clear whitespace from selected group, a SECOND orange hardhat Deployment supervisor tends ONE coral-circle-banded purple Pod, matching coral circle clipboard. Its Pod receives no envelope and is outside the Service's pointing direction. Make spatial hierarchy clear: client and Service form access relationship; supervisors manage labeled Pod groups from above; cyan pair are Service's selected recipients while coral Pod belongs to a different managed group. Exactly 4 purple Pods, 2 orange Deployment supervisors, 1 green Service. Preserve each character's official resource emblem clearly (white cube hexagon Pod, branching Service, circular-arrow Deployment helmet). All full figures visible, consistent scale, clear separations, no overlaps covering marks. Soft white background, subtle grounding shadows, compact intentional triangular grouping, no giant props, arches, doors, boxes, text, captions, arrows, legend or UI. Communicate only through poses, expressions, matching colored tags and placement. Professional polished textbook mascot illustration.

## 두 번째 Deployment 추가

기본 image_gen 도구로 아래 프롬프트를 적용하고 기존 결과 파일을 갱신했습니다.

Edit this existing cute glossy 3D Kubernetes educational illustration. Add a SECOND Deployment supervisor behind the lone coral-orange-circle-tagged purple Pod on the far right, OUTSIDE the green arch. New supervisor matches existing orange hardhat Deployment character with the same white Deployment circular-arrow hexagonal helmet emblem, but its clipboard displays the CORAL ORANGE CIRCLE matching its own Pod's Label. Show it kindly tending that Pod, hand on shoulder or attaching matching tag. Keep first Deployment inside arch behind its TWO cyan-diamond-tagged Pods, its clipboard cyan diamond. Preserve left client Pod with cyan envelope, green Service guide with cyan diamond selector pointing only to cyan group, all four purple Pods, existing emblems, white background, glossy style. Exactly TWO Deployment supervisors, FOUR purple Pods, ONE Service guide. The two separately managed groups must be unmistakable, readable silhouettes and badges with no obscuring overlaps. Widen landscape framing as needed. No words, arrows, captions or added UI. Change only as needed to add the second supervisor and keep balanced spacing.

## 다른 Label 비교를 위한 후속 수정

기본 image_gen 도구로 기존 결과를 수정했습니다. 2.3절에서는 하늘색 마름모 Label의 두 Pod와 주황색 원 Label의 별도 Pod를 비교합니다.

Edit this Kubernetes textbook illustration. Preserve cute glossy 3D style, white background, existing purple client with cyan-sealed envelope on left, green Service guide holding cyan diamond selector, orange Deployment supervisor and EXACTLY TWO purple backend Pods with matching cyan diamond Label bands inside green arch. Add ONE additional purple Pod on far right OUTSIDE the arch and separate from Deployment's two Pods, wearing and visibly holding a coral orange circular Label badge and band (distinct color AND shape from cyan diamonds). Widen/recompose landscape to fit all characters fully without overlap or cropping, preserve original emblems. Service points ONLY toward the two cyan-tagged backend Pods inside arch. Orange-circle-tagged Pod stands neutrally smiling apart, no envelope, no requests sent to it, no rejection/sadness symbol. Exactly FOUR purple Pods total: one client, two selected cyan-label backends, one unselected coral-circle-label backend. Visually obvious matching labels vs different label. No text, captions, arrows, UI or extra characters.

- 도구: 기본 image_gen / imagegen 스킬
- 원본: interaction-service-pods.png
- Deployment 참조: character-deployment.png
- 결과: interaction-service-deployment-labels.png
- 배치: 6장 2.3절

## 생성 프롬프트

Edit the Service interaction illustration, preserving the cute glossy 3D purple Pods, lime green Service guide and archway, official emblems, and white background. Add the orange hardhat Deployment supervisor behind the two destination Pods, tending to both. Give both destination Pods identical cyan label bands with a diamond symbol, and the Deployment clipboard a matching tag. Keep the client Pod separate on the left, holding an envelope with a matching cyan destination ribbon and seal; its body has no cyan label band. Service holds a matching selection swatch and points to the two destination Pods. Exactly three purple Pods. No text, arrows, or explanatory captions. Balanced landscape composition with important marks unobscured.
