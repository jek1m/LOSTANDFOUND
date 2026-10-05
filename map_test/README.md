# LOSTANDFOUND

## Kakao 지도 및 장소 검색 설정

프로젝트 루트의 `.env` 파일에 Kakao JavaScript 키와 웹 도메인을 설정합니다.

```dotenv
KAKAO_JAVASCRIPT_KEY=발급받은_JavaScript_키
KAKAO_BASE_URL=https://등록한_웹_도메인
```

`KAKAO_BASE_URL`은 Kakao Developers의 앱 설정에서 JavaScript 키에 등록한 웹 도메인과 일치해야 합니다. 장소 검색 등 지도 services 기능을 쓸 때 지정하세요. 미설정이면 임의의 도메인을 사용하지 않습니다. 로컬 개발용 도메인도 Kakao Developers에 먼저 등록한 뒤 `.env`에 지정해야 합니다.
