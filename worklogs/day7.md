# [Day 7 Worklog] 실시간 주파수 분석(FFT) 구현 및 오디오 반응형 연출

## 1. 개발 목표
- 게임의 시각적 피드백을 오디오 파형과 완벽하게 동기화하기 위해, 순수 Lua로 고성능 실시간 주파수 분석(FFT) 모듈을 설계합니다.
- 오디오 주파수 대역별(저음/중음/고음) 세기를 3D 터널 크기, 보스 진동, 이퀄라이저 HUD 그래프에 물리 반응하도록 통합 제어합니다.

## 2. 핵심 구현 내용 및 세부 설계
- **Cooley-Tukey Radix-2 FFT 구현**: 256샘플을 대상으로 고속 퓨리에 변환 알고리즘을 구축하여 실시간 스펙트럼 분석 환경을 구성했습니다.
- **오디오 버퍼 이중 로딩**: 메인 메뉴 탐색 중에는 파일 IO 병목을 없애기 위해 오디오 스트리밍을 채택하고, 인게임 시작 시점에만 해당 곡의 오디오 데이터를 정밀 샘플 추출이 가능한 `SoundData` 객체로 메모리에 적재하는 이중 구조를 수립했습니다.
- **오디오 반응성**:
  - 저음(Bass, 1~2 밴드): 터널 그리드와 배경 이미지 밝기의 수축/팽창.
  - 중음(Mid, 3~8 밴드): 디스크 반지름 크기 쿵쿵 진동.
  - 고음(Treble, 9~16 밴드): 디스크 외곽 서클의 물리적인 회전 스피드 가속.

## 3. AI 에이전트 협업 & 프롬프트 예시
- **프롬프트**: "Love2D 60FPS 게임플레이 중에 오디오 실시간 분석(FFT)을 돌리고 싶어. 매 프레임 돌아야 하니 테이블을 동적으로 할당해서 쓰레기 수집기(GC) 과부하가 생기면 절대 안 돼. 배열 값을 인플레이스(In-place)로 교체하고 삼각함수 테이블을 캐싱해두는 최적화된 Radix-2 FFT 코드를 작성해줘."
- **협업 내용**: 에이전트는 비트 리버설 및 복소수 곱셈 팩터인 트위들 계수(`Twiddle Factor`)를 최초 1회 사전 생성하여 테이블 재할당 오버헤드를 제로로 만든 최적의 FFT 연산 알고리즘 모듈을 구축했습니다.

## 4. 디버깅 및 검증 과정
- **문제점**: FFT의 주파수 분해능 중 고주파 영역의 신호 강도가 인간 청각 특성으로 인해 저주파(Bass)에 비해 매우 미미하게 계산되어 바 그래프나 보스 회전 속도에 반영되지 않는 문제가 있었습니다.
- **해결 및 검증**: 각 주파수 대역 인덱스에 따라 선형 가산 게인 보정 수식(`gain = 35 + b * 15`)을 오버레이 렌더러에 매핑하여 고음 밴드도 명확하게 요동치는 네온 그래픽 이퀄라이저를 검증했습니다.

## 5. 핵심 소스코드 블록 및 설명 (`fft.lua` 발췌)
```lua
-- [7일차 구현] GC 부하 방지를 위해 테이블 사전 할당을 완료한 인플레이스 FFT 핵심 루프
local function compute_fft()
    local rev = fft_cache.rev
    local twiddle = fft_cache.twiddle
    
    -- 1. Bit-Reversal 재정렬 (In-place Swap)
    for i = 1, N do
        local j = rev[i]
        if i < j then
            ar[i], ar[j] = ar[j], ar[i]
            ai[i], ai[j] = ai[j], ai[i]
        end
    end
    
    -- 2. Cooley-Tukey 나비 연산 (Butterflies)
    local m = 1
    while m < N do
        local tw = twiddle[m]
        local m2 = m * 2
        for k = 0, N - 1, m2 do
            for j = 1, m do
                local w = tw[j]
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
