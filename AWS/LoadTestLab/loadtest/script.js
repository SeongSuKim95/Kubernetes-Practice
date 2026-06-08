// k6 부하 시나리오: 초당 요청수(RPS)를 100 → 1,000 → 10,000 → 50,000 으로 증가.
// keep-alive(커넥션 재사용)로 임시 포트 고갈 없이 고RPS 를 만듭니다.
//
// 환경변수:
//   APP_HOST   대상 호스트 (예: loadtest.k8s-study.club)  [필수]
//   STAGE_DUR  각 단계 지속시간 (기본 2m)
//   MAX_VUS    선할당 최대 VU (기본 20000)
//
// 실행:
//   APP_HOST=loadtest.k8s-study.club k6 run script.js
import http from 'k6/http';
import { check } from 'k6';

const HOST = __ENV.APP_HOST;
const DUR = __ENV.STAGE_DUR || '2m';
const MAX_VUS = parseInt(__ENV.MAX_VUS || '20000', 10);

if (!HOST) {
  throw new Error('APP_HOST 환경변수를 지정하세요. 예: APP_HOST=loadtest.k8s-study.club');
}

export const options = {
  discardResponseBodies: true,
  scenarios: {
    ramp_rps: {
      executor: 'ramping-arrival-rate',
      startRate: 100,
      timeUnit: '1s',
      preAllocatedVUs: 1000,
      maxVUs: MAX_VUS,
      stages: [
        { target: 100, duration: DUR },     // 100 RPS
        { target: 1000, duration: DUR },    // 1,000 RPS
        { target: 10000, duration: DUR },   // 10,000 RPS
        { target: 50000, duration: DUR },   // 50,000 RPS
      ],
    },
  },
  thresholds: {
    // 목표: 200 응답 100% 유지. 실패율이 0 을 넘으면 threshold 위반으로 표시.
    http_req_failed: ['rate==0'],
  },
};

export default function () {
  const res = http.get(`https://${HOST}/`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}
