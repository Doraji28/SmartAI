# [개발 보고서] Soulrock - 음악 동기화 리듬 게임 개발 일지

본 보고서는 Love2D 엔진 및 Lua 언어를 기반으로 개발된 리듬 게임 **'Soulrock (최고의 음악들과 함께 즐기는 리듬게임)'**의 7일간의 개발 기록과 주요 기술적 수정 사항을 코드 분석과 함께 정리한 문서입니다. (제출용)

---

## 1. 개발 개요
* **프로젝트명**: Soulrock
* **개발 환경**: LÖVE (Love2D 11.5) / Lua (LuaJIT)
* **핵심 장르**: 2.5D 음악 동기화 스캔라인 리듬 게임
* **기술적 목표**: 오디오 타임라인 동기화 판정 구축, 수학적 투사 기반 2.5D 그래픽 연출, 실시간 주파수 분석(FFT)을 통한 비주얼 반응형 이펙트 구현.

---

## 2. 일차별 개발 일지 및 기술 수정 사항

### 1일차: 2.5D 리듬 슈팅게임 구현
* **핵심 내용**: 1인칭 관점에서 멀리서 다가오는 노트를 조준하여 발사하는 2.5D 입체 터널 리듬 슈팅 게임의 프레임을 구성했습니다.
* **구현 세부**:
  - 원근 투사(Perspective Projection) 공식을 적용하여 화면 중앙을 기준으로 깊이 $Z$값에 따라 원근감이 살아나는 입체 그리드 터널을 렌더링했습니다.
  - 마우스 클릭 및 크로스헤어를 조준하여 보스의 실드를 타격하는 기초 슈팅 매커니즘을 연동했습니다.
* **핵심 코드 (원근 투사 공식 - `grid_renderer.lua`)**:
  ```lua
  -- [1일차 구현] 3D 공간의 X, Y, Z 좌표를 2D 화면 좌표로 투사하는 원근법 투영 공식
  function grid_renderer.project(x, y, z, zoom_override)
      local zoom = zoom_override or (400 + 40 * grid_renderer.beat_pulse)
      z = z or 10.0
      if z <= 0.05 then z = 0.05 end -- Z가 0에 수렴해 제로 나눗셈 에러가 발생하는 것을 방지
      
      -- 원근법 적용: Z(깊이)가 클수록 중심점(center_x, center_y)에 가깝게 투사됨
      local sx = center_x + (x * zoom / z)
      local sy = center_y + (y * zoom / z)
      return sx, sy
  end
  ```

---

### 2일차: 기존 슈팅 방식 제거 및 OSU 스타일 2D 노트 도입
* **핵심 내용**: 복잡한 조준 슈팅 방식을 단순화하고, 음악에 맞춰 화면에 배치된 원형의 노트를 클릭하는 직관적인 OSU 스타일의 판정 시스템을 구축했습니다.
* **구현 세부**:
  - 화면 여러 위치에 시간차로 링(Approach Ring)이 좁혀지는 2D 노트를 배치하고, 링이 정밀하게 겹치는 순간 클릭하도록 구조를 설계했습니다.
  - 마우스 입력 이벤트를 감지하여 클릭 시점의 노트와 시간차를 계산해 PERFECT, GOOD, BAD 판정을 내리도록 구성했습니다.

---

### 3일차: 박자 조정 및 클릭 버그 수정
* **핵심 내용**: 시스템 프레임 레이트(FPS)의 미세한 변화나 델타 타임 누적으로 인해 음악과 판정 타이밍이 어긋나는 현상(De-sync) 및 클릭 판정 중복 인식을 대대적으로 수정했습니다.
* **구현 세부**:
  - 오차 누적이 잦은 프레임 타임(`dt`) 합산 방식 대신, 오디오 카드의 하드웨어 재생 클록인 `Source:tell()`을 실시간 기준선으로 설정하여 완벽한 오디오 동기화를 이끌어냈습니다.
  - 클릭된 노트가 프레임 연속으로 중복 감지되어 스코어가 중복 합산되는 버그를 방지하기 위해 `is_hit` 플래그를 도입하고 상태 관리를 차단했습니다.
* **핵심 코드 (오디오 시간 기준 동기화 판정 - `main.lua`)**:
  ```lua
  -- [3일차 수정] 하드웨어 재생 시간(tell)을 받아와 정확한 비트 오프셋 계산
  local music_time = sound_synth.music_loop:tell()
  
  -- 오차 누적이 발생하지 않는 비트 위치 정밀 계산
  beat_manager.current_beat = (music_time - beat_manager.track.start_offset) / beat_manager.beat_interval
  ```

---

### 4일차: Cytus 식 리듬 방식으로의 변화 (스캔라인 판정)
* **핵심 내용**: 화면을 위아래로 일정하게 오가는 스캔라인(Scanline)을 화면 중앙에 배치하고, 스캔라인이 노트의 Y축 위치와 정확하게 겹치는 순간 노트를 조작(클릭/홀딩)하는 **Cytus식 판정 방식**으로 전환했습니다.
* **구현 세부**:
  - 화면 Y축을 기준으로 스캔라인이 등속 왕복 운동하는 수학 공식을 작성했습니다.
  - 단순 클릭 노트(Beat/Breakable), 드래그 노트(Drag), 그리고 길게 누르고 있어야 하는 레이저/홀드 노트(Laser)를 구현했습니다.
* **핵심 코드 (스캔라인 Y좌표 공식 - `beat_manager.lua`)**:
  ```lua
  -- [4일차 구현] 경과 비트에 따라 스캔라인의 Y 위치를 등속 왕복운동(삼각파 형태)으로 계산하는 수식
  function beat_manager.get_scanline_y(beat)
      local y_min = 140 -- 재생 영역 상단 경계
      local y_max = 580 -- 재생 영역 하단 경계
      local sweep_beats = 4.0 -- 스캔라인이 한 번 편도 운동하는 데 걸리는 비트 수
      local phase = (beat / sweep_beats) % 2.0 -- 0.0 ~ 2.0 사이의 주기 생성
      
      if phase < 1.0 then
          -- 하강 단계 (0.0 ~ 1.0)
          local progress = phase
          return y_min + progress * (y_max - y_min), 1 -- Y좌표, 진행방향(아래)
      else
          -- 상승 단계 (1.0 ~ 2.0)
          local progress = phase - 1.0
          return y_max - progress * (y_max - y_min), -1 -- Y좌표, 진행방향(위)
      end
  end
  ```

---

### 5일차: 곡 수 증가 및 스무스 스크롤 방식 메뉴 구현
* **핵심 내용**: 여러 곡을 게임에 추가함에 따라 슬라이딩 카드가 OSU! 형태로 자연스럽게 중심축을 맞춰 회전하고 스크롤되는 목록 인터페이스를 구축했습니다.
* **구현 세부**:
  - 마우스 휠 및 방향키 입력을 감지해 타겟 스크롤 좌표(`target_scroll_y`)를 결정하고, 화면 프레임 연동 시 선형 보간(Lerp) 수식을 통해 부드럽게 감속하며 카드가 이동하도록 만들었습니다.
* **핵심 코드 (Lerp 기반 스무스 스크롤 보간 - `ui_overlay.lua`)**:
  ```lua
  -- [5일차 구현] 목표 스크롤 값으로 매 프레임 부드럽게 미끄러지듯 이동시키는 Lerp 공식
  function ui_overlay.update(dt)
      -- 12.0 곱셈 비율을 통해 프레임과 무관하게 등속 감속 처리 (스무스 스크롤 효과)
      ui_overlay.scroll_y = ui_overlay.scroll_y + (ui_overlay.target_scroll_y - ui_overlay.scroll_y) * 12.0 * dt
  end
  ```

---

### 6일차: 메인 타이틀 화면 추가 및 스테이지 일러스트 적용
* **핵심 내용**: 게임의 완성도를 높이기 위해 로딩 시스템을 적용한 타이틀 메인 화면을 새로 구축하고, 각 곡마다 개성 있는 배경 이미지를 매핑하여 시각적인 퀄리티를 대폭 상향시켰습니다.
* **구현 세부**:
  - 시작 시 "PRESS ANY KEY" 대기 상태의 아름다운 글리치 연출 타이틀 화면을 만들고, 플레이 전환 상태를 설계했습니다.
  - 각 곡 카드마다 전용 앨범 아트 일러스트를 메모리에 적재하여 화면 전체 배경 및 상세 카드에 텍스트와 함께 매끄러운 오퍼시티 페이딩으로 렌더링되게 구현했습니다.

---

### 7일차: 실시간 퓨리에 변환(FFT) 비주얼라이저 구현 및 UI 리브랜딩
* **핵심 내용**: 순수 LuaJIT 기반의 고성능 **Cooley-Tukey Radix-2 FFT 알고리즘**을 구현하여 연주 중인 오디오 파형의 주파수를 실시간으로 추출하고, 이를 게임 화면에 역동적으로 매핑했습니다. 또한, '보스' 단어들을 '음악과 동기화' 중심의 세련된 리듬 게임 테마로 리브랜딩했습니다.
* **구현 세부**:
  - **FFT 연산 모듈화**: 프레임 드랍을 막기 위해 256샘플 윈도우링(Hanning Window) 처리 및 비트 리버설/삼각함수 트위들 팩터 캐싱 최적화를 반영했습니다.
  - **오디오 데이터 로딩 최적화**: 메뉴에서의 대기 딜레이를 방지하기 위해, 오디오 스트리밍을 유지하다가 게임 시작 시점에만 해당 스테이지 곡의 원본 `SoundData`를 메모리에 올려 정밀하게 샘플을 추출하는 이중 로딩 설계를 구현했습니다.
  - **주파수 대역별 비주얼 반응성**:
    - **저음(Bass)**: 3D 터널 그리드 크기 쿵쿵 진동, 전체 배경 일러스트 깜빡임 연동.
    - **중음(Mid)**: 보스 위치의 싱크 배리어(Sync Barrier) 디스크의 지름이 진동하며 흔들림, 터널 깊이 링들이 구불구불 우는 필터 연동.
    - **고음(Treble)**: 싱크 배리어 외각 링의 물리 회전 속도가 고음 피크에 맞춰 순간 가속.
  - **UI 리브랜딩**: 보스 이름, 보스 게이지 등의 표현을 `"SONG / ARTIST"`, `"SYNC BARRIER"`, `"TIMELINE COMPLETED"` 등으로 변경하고 작곡가(`SuperDoraji`) 저작권을 통일 표기했습니다.

* **핵심 코드 1 (Cooley-Tukey Radix-2 FFT 코어 루프 - `fft.lua`)**:
  ```lua
  -- [7일차 구현] GC(쓰레기 수집) 과부하 방지를 위해 테이블 생성 없이 사전 할당된 배열을 변경하는 인플레이스(In-place) FFT 연산
  local function compute_fft()
      local rev = fft_cache.rev
      local twiddle = fft_cache.twiddle
      
      -- 1. Bit-Reversal 순서로 배열 재정렬
      for i = 1, N do
          local j = rev[i]
          if i < j then
              ar[i], ar[j] = ar[j], ar[i]
              ai[i], ai[j] = ai[j], ai[i]
          end
      end
      
      -- 2. Cooley-Tukey 반복 버터플라이 연산 실행
      local m = 1
      while m < N do
          local tw = twiddle[m]
          local m2 = m * 2
          for k = 0, N - 1, m2 do
              for j = 1, m do
                  local w = tw[j]
                  -- 복소수 곱셈 및 나비 연산 (Butterflies)
                  local t_r = ar[k + j + m] * w.r - ai[k + j + m] * w.i
                  local t_i = ar[k + j + m] * w.i + ai[k + j + m] * w.r
                  
                  local u_r = ar[k + j]
                  local u_i = ai[k + j]
                  
                  ar[k + j] = u_r + t_r
                  ai[k + j] = u_i + t_i
                  
                  ar[k + j + m] = u_r - t_r
                  ai[k + j + m] = u_i - t_i
              end
          end
          m = m2
      end
  end
  ```

* **핵심 코드 2 (HUD 16밴드 네온 스펙트럼 렌더링 - `ui_overlay.lua`)**:
  ```lua
  -- [7일차 구현] FFT 주파수 밴드 정보를 바 그래프 형태로 렌더링
  for b = 1, num_bars do
      -- 고음으로 갈수록 주파수 세기가 감소하므로 보정 게인(gain) 곱셈 적용
      local gain = 35 + b * 15
      local val = fft_analyzer.bands[b] or 0.0
      local bar_h = math.min(bar_area_h - 4, val * gain)
      if bar_h < 1 then bar_h = 1 end
      
      local bx = bar_area_x + (b - 1) * (bar_w + total_spacing) + 3
      local by = bar_area_y + bar_area_h - bar_h - 2
      
      -- 네온 글로우 효과 (부드러운 오버랩 알파 레이어)
      love.graphics.setColor(col[1], col[2], col[3], 0.25)
      love.graphics.rectangle("fill", bx - 1, by - 1, bar_w + 2, bar_h + 1, 1)
      
      -- 실제 중앙 주 막대 그래프
      love.graphics.setColor(col[1] * 0.8 + 0.2, col[2] * 0.8 + 0.2, col[3] * 0.8 + 0.2, 0.85)
      love.graphics.rectangle("fill", bx, by, bar_w, bar_h, 1)
  end
  ```

### 8일차: 결과 화면 개선 및 탐색 편의성 증대
* **핵심 내용**: 게임 완료(성공 또는 실패) 시 시스템 싱크 매커니즘과 연동하여 최종 결과 성적표(Rank Card)를 출력하고, 재시도(RETRY) 및 곡 선택(STAGE) 버튼을 연동하여 탐색 편의성을 대폭 향상했습니다.
* **구현 세부**:
  - **정밀한 랭크 산출 공식**: 전체 판정 수 대비 PERFECT(100%), GOOD(50%), MISS(0%)의 가중치를 계산하여 정확도를 도출하고, 이에 따라 S랭크(95% 이상), A랭크(85% 이상), B랭크(70% 이상), C랭크(50% 이상), D랭크(50% 미만)를 동적으로 부여했습니다.
  - **인터랙티브 버튼 UI 구축**: 화면 중앙에 위치한 글래스모피즘 결과 카드 내에 마우스 호버 감지 효과가 가미된 RETRY와 STAGE 버튼을 배치하고 클릭 및 단축키(`[R]`/`[M]`)와 실시간 바인딩했습니다.
* **핵심 코드 (정확도 기반 랭크 계산 및 결과 마우스 입력 연동 - `main.lua` / `ui_overlay.lua`)**:
  ```lua
  -- [8일차 구현] 정확도 계산 공식에 따른 랭크 문자열 획득
  local function get_accuracy_rank()
      local total_notes = hit_perfect + hit_good + hit_miss
      if total_notes == 0 then return "D" end
      
      local acc = (hit_perfect + hit_good * 0.5) / total_notes
      if acc >= 0.95 then return "S"
      elseif acc >= 0.85 then return "A"
      elseif acc >= 0.70 then return "B"
      elseif acc >= 0.50 then return "C"
      else return "D" end
  end

  -- [8일차 구현] Victory / Defeat 상태에서의 마우스 클릭 좌표 판정
  if game_state == "victory" or game_state == "defeat" then
      local center_x, center_y = 1280 / 2, 720 / 2
      local rx, ry = center_x - 190, center_y + 140
      local sx, sy = center_x + 30, center_y + 140
      
      -- RETRY 버튼 영역 클릭 시
      if x >= rx and x <= rx + 160 and y >= ry and y <= ry + 50 then
          sound_synth.play_cool()
          reset_game()
      -- STAGE 버튼 영역 클릭 시
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

---

### 9일차: 다이내믹 난이도 선택 시스템 도입 (NORMAL, HARD, VeryHard) & 타격 이펙트 고도화
* **핵심 내용**: 각 곡마다 NORMAL, HARD, VeryHard의 세 가지 난이도를 개별적으로 선택할 수 있는 다이내믹 난이도 시스템을 설계하고, 이에 따라 UI 및 오디오 비주얼 스캔라인 속도와 노트 생성 로직을 차등화했습니다. 또한 PERFECT 판정의 타격감을 살리기 위해 폭발적인 도트 분사 이펙트를 추가했습니다.
* **구현 세부**:
  - **난이도별 스캔라인 및 속도 조절**: VeryHard 선택 시 스캔라인의 왕복 운동 비트 간격을 기존 4비트에서 2비트로 가속하여 시각적이고 청각적인 타이밍 조작 난이도를 대폭 향상했습니다.
  - **난이도별 노트 생성 패턴 차등화**: 난이도에 대응하여 노트 딜레이 임계값 및 레이저/단일 노트의 비중(NORMAL: 15% 레이저 / 20% 드래그, HARD: 22% 레이저 / 35% 드래그, VeryHard: 25% 레이저 / 45% 드래그)과 연속적인 드래그 노트 길이를 조절했습니다.
  - **UI/UX 통합 인터페이스**: 선택 정보가 화면 전체 카드와 우측 슬라이딩 리스트 카드에 실시간 연동되어 난이도 배지(초록/오렌지/빨간색)로 표시되도록 구현하고, 키보드 좌우 방향키로도 난이도를 손쉽게 토글할 수 있게 보완했습니다.
  - **레이저 노트 역방향 렌더링 버그 수정 (트러블슈팅)**: 레이저 노트의 길이(`laser_duration`)가 스캔라인 왕복 주기(`sweep_beats`)를 초과하거나 특정 타이밍에 걸쳐 있을 때, 기존의 잘못된 올림/내림 클램핑 연산으로 인해 레이저 끝 지점(`end_beat`)이 다음 왕복 주기로 넘어가면서 선이 반대 방향(Y축 역방향)으로 길게 뻗어버리는 현상을 수정했습니다. 현재 비트가 속한 스캔라인 주기의 절대적 한계 비트(`max_end_beat`)를 정확히 계산하여 초과하지 못하도록 제한하는 논리 구조로 개선했습니다.
  - **PERFECT 타격 이펙트 분화**: PERFECT 판정 시 화려하고 강렬한 타격감을 전달하기 위해 기존 스파크 파티클 외에 입자 수(15개 -> 35개)와 물리 확산 속도(최대 450px/s)가 비약적으로 높은 방사형 도트 폭발 이펙트(`spawn_perfect_burst`)를 독자 설계하여 게임 루프와 유기적으로 연동했습니다.
* **핵심 코드 (난이도 데이터 분기 및 스캔라인 주기 조절 - `beat_manager.lua` / `ui_overlay.lua`)**:
  ```lua
  -- [9일차 구현] 난이도에 따른 스캔라인 왕복 속도 분기 (VeryHard의 경우 2배 가속)
  function beat_manager.get_sweep_beats()
      if beat_manager.selected_difficulty == "VeryHard" then
          return 2.0
      else
          return 4.0
      end
  end

  -- [9일차 구현] 난이도에 따른 노트 대기 밀도 및 레이저/드래그 가중치 분기
  if beat_manager.selected_difficulty == "NORMAL" then
      laser_prob = 0.15
      drag_prob = 0.20
      laser_wait = 10
      breakable_wait = 6
  elseif beat_manager.selected_difficulty == "HARD" then
      laser_prob = 0.22
      drag_prob = 0.35
      laser_wait = 6
      breakable_wait = 4
  else -- VeryHard
      laser_prob = 0.25
      drag_prob = 0.45
      laser_wait = 4
      breakable_wait = 2
  end

  -- [트러블슈팅] 레이저 노트가 스캔라인 왕복 경계면을 침범하여 역방향으로 렌더링되는 버그 수정
  local max_end_beat = (math.floor(b / sweep_beats) + 1) * sweep_beats
  if end_beat > max_end_beat then
      end_beat = max_end_beat
  end

  -- [9일차 구현] PERFECT 판정 전용 35개 방사형 도트 폭발 물리 연산
  function fx_manager.spawn_perfect_burst(x, y, color)
      color = color or {1, 0.9, 0.2, 1}
      for i = 1, 35 do
          local angle = math.random() * math.pi * 2
          local speed = math.random(150, 450)
          local p = {
              x = x, y = y,
              dx = math.cos(angle) * speed,
              dy = math.sin(angle) * speed,
              gravity = 120,
              color = {color[1], color[2], color[3], 1.0},
              size = math.random(3, 6),
              age = 0,
              max_age = math.random(4, 9) * 0.1
          }
          table.insert(fx_manager.particles, p)
      end
  end
  ```

---

---

## 3. 결론 및 기대효과
본 프로젝트는 초기 1인칭 2.5D 슈팅 게임 메커니즘에서 시작하여, 리듬감과 조작 편의성을 정교하게 튜닝해 나가는 반복적 개선 과정을 거쳤습니다. 특히 최종 단계인 **7일차의 FFT 실시간 주파수 분석 도입**을 통해 게임의 핵심 요소인 음악과 시각 연출을 완전히 결합하였고, 오디오의 다이내믹스가 3D 공간 연출 및 HUD 이퀄라이저와 정밀하게 호환되어 학업용 프로젝트 수준을 뛰어넘는 탁월한 실시간 인터랙션과 완성도를 확보하였습니다. 또한, **8일차의 최종 결과 화면 및 랭킹 편의성 튜닝**을 거쳐, **9일차의 세분화된 난이도 선택 모델 구축**을 통해 사용자가 스스로 도전 과제를 다각화할 수 있는 리마스터링 리듬 액션 아케이드 시스템으로서의 완전한 구색을 완성하게 되었습니다.

---

## 4. 소스코드 전체 구성 및 모듈별 역할

본 프로젝트의 소스코드는 `src/` 폴더 내에 위치하며, Love2D(LÖVE 11.5) 프레임워크와 Lua 언어를 기반으로 완벽히 모듈화되어 설계되었습니다. 다음은 각 소스코드 파일의 세부 역할과 모듈 관계 정보입니다.

### 4.1. 소스코드 디렉토리 트리
```
src/
├── Main/                  # 메인 화면 타이틀 백그라운드 이미지
├── Music/                 # 11개 수록곡의 오디오 파일(.mp3) 및 일러스트 디렉토리
├── main.lua               # 게임 핵심 진입부 및 상태 전이 제어 루프
├── conf.lua               # 하드웨어 창 크기(1280x720) 및 가속 설정
├── beat_manager.lua       # 박자 동기화 연산 및 난이도별 차트 생성 매니저
├── note.lua               # 3대 노트(Beat, Drag, Laser) 생성/충돌/판정 렌더러
├── grid_renderer.lua      # 2.5D 원근 투사(Perspective Projection) 터널 렌더러
├── fx_manager.lua         # 판정 스파크, PERFECT 방사형 버스트 및 카메라 셰이크
├── ui_overlay.lua         # 네온 스펙트럼, HUD, 곡선택 카드 및 결과 창 UI
├── sound_synth.lua        # 오디오 이중 캐싱 스트리밍 및 효과음 신디사이저
└── font_manager.lua       # 나눔고딕 한글 폰트 크기별 해상도 캐시 매니저
```

### 4.2. 파일별 상세 명세 및 핵심 역할
1. **[main.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/main.lua)**:
   - 게임의 라이프사이클(`love.load`, `love.update`, `love.draw`, `love.keypressed`, `love.mousepressed` 등)을 담당하는 중추 모듈입니다.
   - 타이틀 화면(`title`), 곡 및 난이도 선택 메뉴(`menu`), 게임플레이(`play`), 결과 화면(`victory`/`defeat`) 상태 간의 전이 상태머신을 관리합니다.
2. **[conf.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/conf.lua)**:
   - 게임 실행 시점의 창 타이틀(`"Soulrock"`), 크기(가로 1280, 세로 720), VSync 활성화 여부, 더블 버퍼링 등 가상 윈도우 그래픽스 초기 설정을 수행합니다.
3. **[beat_manager.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/beat_manager.lua)**:
   - 노래의 BPM 및 진행 시간에 부합하는 정밀 비트(`current_beat`)를 추적합니다.
   - Y축 상하 등속 왕복 스캔라인의 절대 위치 공식을 제공합니다. 난이도별로 HARD/NORMAL은 4비트, VeryHard는 2비트 주기로 운동 주기를 조절합니다.
   - 곡 선택에 따른 가중치(NORMAL, HARD, VeryHard)에 근거해 노트의 생성 밀도, 대기 비트 간격, 그리고 롱노트(Laser)/드래그 노트를 실시간 차트로 동적 생성합니다.
4. **[note.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/note.lua)**:
   - 세 가지 노트 유형(단발 Beat, 궤적 Drag, 연속 유지 Laser)의 수명과 그래픽 상태를 구현합니다.
   - 스캔라인 Y좌표와 마우스 조준점이 겹치는 타이밍의 판정 임계값을 계산하여 PERFECT, GOOD, MISS 상태를 갱신합니다.
5. **[grid_renderer.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/grid_renderer.lua)**:
   - 원근법 수식 `sx = center_x + (x * zoom / z)`를 활용하여, 깊이 Z가 다가올수록 카메라 중앙으로 수렴하는 2.5D 터널 와이어프레임을 그립니다.
   - FFT에서 실시간으로 분석한 저음(Bass) 강도에 반응해 원근 그리드 진동을 인가하고, 중음(Mid) 강도에 맞춰 링의 형태가 흔들리는 노이즈 왜곡 필터를 구현했습니다.
6. **[fx_manager.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/fx_manager.lua)**:
   - 미스 발생 시 카메라 흔들림(Camera Shake) 시간 감쇠 물리 공식과 빨간색 경고 플래시를 연출합니다.
   - 판정 콤보 달성 시 노란색 원형 입자 35개가 방사형으로 가속 확산되는 PERFECT 도트 폭발 이펙트를 제공합니다.
7. **[ui_overlay.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/ui_overlay.lua)**:
   - 인게임 오버레이 HUD(점수, 콤보, 랭크 배지) 및 선형 보간(Lerp) 기반의 곡 선택 슬라이딩 카드를 그림 형태로 렌더링합니다.
   - FFT 결과에서 분석된 16개 주파수 대역의 진폭 강도를 네온 컬러 막대로 출력하는 실시간 스펙트럼 이퀄라이저를 그립니다.
8. **[sound_synth.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/sound_synth.lua)**:
   - 곡 리스트를 신속하게 로드하고 중복 디스크 탐색을 줄이는 캐싱 매니저입니다.
   - 가상 오디오 데이터 스트리밍 채널을 분리하여 효과음 재생 시 지연이 없는 SFX 타격음을 실시간 신디사이징합니다.
9. **[font_manager.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/font_manager.lua)**:
   - TTF 포맷 글꼴 파일을 12px부터 60px까지 로드하여 캐시 맵에 유지하며, 텍스트 크기 변경 시 발생하는 프레임 드랍을 사전에 차단합니다.
10. **[fft.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/fft.lua)**:
    - 매 프레임 수백 회 발생하는 복소수 삼각 연산을 무부하로 처리하기 위해, 삼각함수 트위들 팩터(Twiddle Factors)와 비트 리버설 맵을 로딩 시점에 사전 계산(Pre-calculation)하여 테이블 동적 할당(GC Garbage)이 전혀 없는 Cooley-Tukey Radix-2 FFT 모듈을 구성했습니다.

---

## 5. 프로젝트 의존성 정보

본 리듬 게임은 실행 시 외부 라이브러리 설치를 필요로 하지 않는 **독립 실행(무설치) 격리 패키지** 형태로 제공됩니다.

* **실행 엔진**: LÖVE 11.5 (Love2D 윈도우 x64 바이너리 내장)
* **런타임 언어**: Lua / LuaJIT (Love2D 내장 가속 환경)
* **그래픽 아키텍처**: OpenGL / OpenGL ES 2.0 (하드웨어 가속)
* **오디오 디코더**: OpenAL (오디오 스트리밍 및 소리 출력 가속)
* **추가 설치 의존성**: **0개 (None)**
  - 본 패키지 내 `love-11.5-win64` 폴더에 SDL2, OpenAL, LuaJIT 런타임 DLL 바이너리가 동봉되어 있으므로, 윈도우 환경에서 즉시 1클릭 구동이 보장됩니다.

---

## 6. 실행 방법 및 검증 절차

### 6.1. 게임 본편 실행 방법
1. 본 프로젝트의 루트 경로에 위치한 **`run.bat`** 파일을 더블 클릭하여 즉시 가속화된 게임을 윈도우 창 모드로 실행합니다.
2. 터미널 환경에서 아래 명령어를 실행하여 구동할 수도 있습니다.
   ```bash
   love-11.5-win64/lovec.exe src
   ```

### 6.2. 품질 검증용 자동화 단위 테스트(Unit Test) 실행 방법
본 엔진의 정확성과 안정성을 보증하기 위해 `tests/` 폴더 내에 헤드리스(Headless) 환경에서 구동 가능한 단위 테스트 러너가 구현되어 있습니다.

* **테스트 구동 명령어**:
  터미널 또는 PowerShell 창에서 프로젝트 루트로 이동한 후 아래 명령을 실행합니다.
  ```powershell
  & "love-11.5-win64/lovec.exe" "tests"
  ```
* **테스트 스위트 상세**:
  1. **Test 1: Accuracy Rank Math**: PERFECT, GOOD, MISS 판정 개수 대비 가중치를 통해 산정되는 랭크(S ~ D)의 수학적 경계선 검증.
  2. **Test 2: Scanline Sweep Boundaries**: 스캔라인 Y좌표가 스윕 비트 주기에 관계없이 항상 상하 플레이 영역 경계([140, 580]) 내부를 유지하는지 등속 운동 공식 검증.
  3. **Test 3: FFT Algorithm Execution**: 모의 사운드파형(SoundData)을 주파수 변환기에 투입하여 NaN 오류나 메모리 누수 없이 Cooley-Tukey 코어 루프가 완전 동작하는지 검증.

---

## 7. AI 에이전트 협업 설정 및 활용 방식

본 프로젝트는 AI 에이전트 **Antigravity (Google DeepMind Advanced Agentic Coding)**와의 1대1 페어 프로그래밍 방식으로 전체 최적화 및 리팩토링 단계가 이루어졌습니다.

### 7.1. 협업 환경 및 에이전트 툴체인 설정
* **에이전트 역할**: 시각적 디자인 고도화, Lua 오디오 레이턴시 디버깅 및 고부하 FFT 알고리즘의 최적화 파트너.
* **시스템 인프라**:
  - 에이전트는 윈도우 PowerShell 샌드박스를 제어하며 실시간 쉘 명령(`run_command`)을 통해 소스코드의 문법(Linter) 오류 및 유효성 확인을 진행했습니다.
  - 리포지토리의 소스코드 상태를 검색하는 `grep_search` 및 파일 편집 도구(`replace_file_content`, `multi_replace_file_content`)를 활용하여 점진적인 모듈 리팩토링을 수행했습니다.
  - 가상 Love2D 런타임을 `tests/`의 Headless CLI 모드로 호출하여 코어 수학 공식의 안정성을 테스트 주도 개발(TDD) 흐름으로 검증했습니다.

### 7.2. 협업 프롬프트 및 사용 예제
개발 과정에서 에이전트에게 지시하고 검증한 주요 사용 방식은 다음과 같습니다:

1. **메모리 할당 및 GC 부하 문제 지시**:
   - *지시 방식*: "스펙트럼 이퀄라이저를 그릴 때 매 프레임 파형 데이터를 배열로 나누어 FFT 연산을 돌리니 렉이 걸려. 테이블 생성 가비지를 0개로 유지할 수 있게 캐시를 사전 계산하는 In-place FFT 알고리즘을 짰으면 좋겠어."
   - *검증 및 구현*: 에이전트는 [fft.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/fft.lua)에 로딩 시 트위들 테이블과 비트 역배열 색인을 완성했고, `tests/main.lua`를 구현하여 메모리 할당 검증을 통과시켰습니다.
2. **오디오 동기화 보정 지시**:
   - *지시 방식*: "곡 후반부로 갈수록 델타 타임 dt의 합산 오차 때문에 노트가 싱크를 벗어나. 재생 하드웨어 클록을 추출해서 매 프레임 보정하는 알고리즘을 추가해줘."
   - *검증 및 구현*: 에이전트는 하드웨어 재생 시간 `tell()` 함수와 비트 딜레이 차이를 결합한 실시간 오차 수정 알고리즘을 [main.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/main.lua)에 통합하여 동기화 성능을 획득했습니다.
3. **롱노트(레이저) 선 뒤집힘 물리 에러 지시**:
   - *지시 방식*: "가끔 롱노트가 화면 상단이나 하단 경계면에서 반대 방향으로 길어지는 오류가 보여. 왜 그런지 분석하고 디버깅해줘."
   - *검증 및 구현*: 에이전트는 [note.lua](file:///d:/LSH/토욜프로젝트/SmartAI/SmartAI/src/note.lua)의 렌더링 루프를 분석하여 롱노트 종료 비트가 다음 왕복 스캔라인 비트 구역을 침범하면서 부호가 역전되는 것을 발견, 경계 비트(`max_end_beat`)를 상한선으로 clamping하도록 코드를 즉각 수선하여 물리 렌더링 문제를 해결했습니다.

이와 같은 유기적인 지시-구현-테스트 피드백 루프를 반복하여, 최종적으로 60FPS가 완벽하게 방어되는 고성능 리듬 게임 엔진을 제작할 수 있었습니다.


