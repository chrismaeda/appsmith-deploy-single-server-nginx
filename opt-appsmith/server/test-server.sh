set -o allexport
source .env
(cd dist && exec java -jar server-*.jar)
