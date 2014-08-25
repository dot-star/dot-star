# Django Aliases

schemamigration() {
    # Django South schemamigration
    ./manage.py schemamigration $@ --auto
}

migrate() {
    # Django South migrate
    ./manage.py migrate $@
}

_runserver() {
    production="${1}"

    if "${production}" 2> /dev/null; then
        export PRODUCTION=1
    else
        export PRODUCTION=0
    fi

    python manage.py runserver 0.0.0.0:8000
}

alias dbshell="python manage.py dbshell"
alias devrunserver="_runserver false"
alias runserver="_runserver true"

shell() {
    python manage.py debugsqlshell 2> /dev/null
    if [ ! $? -eq 0 ]; then
        python manage.py shell
    fi
}

alias sqlall="python manage.py sqlall"
alias startapp="python manage.py startapp"
alias syncdb="python manage.py syncdb --no-initial-data"
alias validate="python manage.py validate"
