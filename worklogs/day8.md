# [Day 8 Worklog] 결과 성적표(S~D랭크) 화면 및 탐색 버튼 구현

## 1. 개발 목표
- 인게임 종료(완곡 성공 또는 HP 소실 실패) 시 점수, 콤보, 랭킹을 한눈에 확인할 수 있는 미려한 결과 요약 카드(Result Card) UI를 만듭니다.
- 키보드 핫키 및 마우스 클릭으로 간편하게 재시작(RETRY)하고 곡 선택화면(STAGE)으로 되돌아갈 수 있도록 전용 버튼 인터랙션을 설계합니다.

## 2. 핵심 구현 내용 및 세부 설계
- **정확도(Accuracy) 및 랭크 연산**: PERFECT 판정(1.0), GOOD 판정(0.5), MISS 판정(0.0) 가중 정확도를 계산하여 점수 등급을 계산하는 수학식을 도입했습니다. (S: 95% 이상, A: 85% 이상, B: 70% 이상, C: 50% 이상, D: 50% 미만)
- **UI 및 클릭 충돌 영역 설계**: 마우스 클릭 위치 좌표 $X, Y$를 버튼의 좌상단 및 우하단 경계 박스와 대조하는 물리 충돌 검사 로직을 수립했습니다.

## 3. AI 에이전트 협업 & 프롬프트 예시
- **프롬프트**: "결과 카드 하단에 RETRY와 STAGE 두 개의 가로 160, 세로 50짜리 버튼을 렌더링하고, 마우스가 버튼 위에 있으면 하이라이트 경계선이 진해지는 효과를 그리고 싶어. 그리고 클릭하면 main.lua에서 인지해서 재시작 및 메인 메뉴 전환 음을 출력하게 해줘."
- **협업 내용**: 에이전트는 결과 카드가 화면 중앙 정렬 상태일 때 기준선을 바탕으로 정확한 상대 오프셋 좌표를 구하고 마우스 호버(`hover`) 감지 플래그 연동 렌더링 코드를 작성했습니다.

## 4. 디버깅 및 검증 과정
- **문제점**: UI 렌더링에서 지정한 버튼의 Y 좌표축(`btn_y = 500`)과 `main.lua` 마우스 클릭 검출 코드의 Y 좌표 범위(`center_y + 160 = 520` 기점) 간에 약 20픽셀의 미스매치가 발생하여 버튼 윗부분을 누르면 작동하지 않는 심각한 오차가 발견되었습니다.
- **해결 및 검증**: `main.lua` 내 클릭 판정 식의 Y 오프셋을 `center_y + 140` (정확히 Y = 500)으로 맞춰 보정함으로써 상호 작용 범위가 일대일로 완벽하게 대응하도록 수정하고 검증을 완료했습니다.

## 5. 핵심 소스코드 블록 및 설명 (`main.lua` 발췌)
```lua
-- [8일차 구현] 결과 화면(Victory/Defeat) 버튼 영역에 대한 정밀 마우스 클릭 처리
if game_state == "victory" or game_state == "defeat" then
    local center_x, center_y = 1280 / 2, 720 / 2
    local rx, ry = center_x - 190, center_y + 140 -- ry = 500 (ui_overlay와 완벽 동치)
    local sx, sy = center_x + 30, center_y + 140  -- sy = 500
    
    -- RETRY 버튼 클릭 판정
    if x >= rx and x <= rx + 160 and y >= ry and y <= ry + 50 then
        sound_synth.play_cool()
        reset_game()
    -- STAGE 버튼 클릭 판정
    elseif x >= sx and x <= sx + 160 and y >= sy and y <= sy + 50 then
        sound_synth.play_cool()
        game_state = "menu"
        sound_synth.music_loop:stop()
        sound_synth.select_track(ui_overlay.selected_idx)
        sound_synth.music_loop:seek(0)
        sound_synth.music_loop:play()
    end
    return
end
```
