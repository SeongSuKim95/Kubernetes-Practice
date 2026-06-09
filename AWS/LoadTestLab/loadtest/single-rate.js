// 단일 RPS 고정 부하 (한 단계만 집중 관찰할 때).
// 환경변수:
//   APP_HOST[필수], TARGET_RATE(기본 1000), STAGE_DUR(기본 2m)
//   PRE_VUS — 시작 VU (기본 max(RATE*5, 300). 느린 백엔드에서 dropped_iterations 방지)
//   MAX_VUS(기본 20000)
import http from 'k6/http';
import { check } from 'k6';

const HOST = __ENV.APP_HOST;
const RATE = parseInt(__ENV.TARGET_RATE || '1000', 10);
const DUR = __ENV.STAGE_DUR || '2m';
const PRE_VUS = parseInt(__ENV.PRE_VUS || String(Math.max(RATE * 5, 300)), 10);
const MAX_VUS = parseInt(__ENV.MAX_VUS || '20000', 10);

if (!HOST) {
  throw new Error('APP_HOST 환경변수를 지정하세요. 예: APP_HOST=loadtest.k8s-study.club');
}

export const options = {
  discardResponseBodies: true,
  scenarios: {
    fixed_rps: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: DUR,
      preAllocatedVUs: PRE_VUS,
      maxVUs: Math.max(MAX_VUS, PRE_VUS),
    },
  },
  thresholds: {
    http_req_failed: ['rate==0'],
  },
};

export default function () {
  const res = http.get(`https://${HOST}/`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}
