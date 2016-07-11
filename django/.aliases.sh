# Django Aliases

makemigrations() {
    python manage.py makemigrations $@
}

migrate() {
    python manage.py migrate $@
}

createsuperuser() {
    python manage.py createsuperuser $@
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
alias rs="runserver"

shell() {
    python manage.py debugsqlshell 2> /dev/null
    if [ ! $? -eq 0 ]; then
        python manage.py shell
    fi
}

alias sqlall="python manage.py sqlall"
alias startapp="python manage.py startapp"
alias startproject="python manage.py startproject"
alias syncdb="python manage.py syncdb --no-initial-data"
alias validate="python manage.py validate"
