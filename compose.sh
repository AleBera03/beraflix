source .env

mkdir -p $MEDIA_PATH/data/torrents/{tv,movies,music,books}
mkdir -p $MEDIA_PATH/data/media/{tv,movies,music,books}

docker-compose up -d