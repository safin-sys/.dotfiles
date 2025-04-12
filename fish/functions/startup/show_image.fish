function show_image
    set -l choice (random 1 4)
    set -l image_path /tmp/random.jpg
    set -l image_caption ""
    set -l url ""

    switch $choice
        case 1
            set url (curl -s https://dog.ceo/api/breeds/image/random | jq -r .message)
            set image_caption "🐶 Here's a good boy."
        case 2
            set url (curl -s https://api.thecatapi.com/v1/images/search | jq -r '.[0].url')
            set image_caption "🐱 Cat: silently judging you."
        case 3
            set -l page (curl -s https://commons.wikimedia.org/wiki/Main_Page)
            set url (echo $page | grep -o 'upload.wikimedia.org[^"]*' | head -n 1)
            set url "https://$url"
            set image_caption (echo $page | grep -oP '(?<=<div class="mainPagePotdDescription">).*?(?=</div>)' | sed 's/<[^>]*>//g' | head -n 1)
        case 4
            set -l json (curl -s "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1")
            set -l path (echo $json | jq -r '.images[0].url')
            set url "https://www.bing.com$path"
            set image_caption (echo $json | jq -r '.images[0].copyright')
    end

    if test -n "$url"
        curl -s "$url" -o $image_path
        if test -f $image_path
            kitty +kitten icat --align=left $image_path
            echo ""
            echo -e (set_color yellow)"$image_caption"(set_color normal)
            echo ""
        else
            echo "⚠️ Failed to download image from $url"
        end
    else
        echo "⚠️ Image URL was empty!"
    end
end

show_image
