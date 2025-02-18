php83_switch_to() {
    echo "current version:"
    php -v
    which php
    echo

    echo "switching to php 8.3"
    brew install php@8.3
    brew link --overwrite php@8.3
    echo

    echo "current version is now:"
    php -v
    which php
}

php85_switch_to() {
    echo "current version:"
    php -v
    which php
    echo

    echo "switching to php 8.5"
    brew install php@8.5
    brew link --overwrite php@8.5
    echo

    echo "current version is now:"
    php -v
    which php
}
