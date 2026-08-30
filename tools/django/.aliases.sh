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

django_runserver() {
    production="${1}"

    if "${production}" 2>/dev/null; then
        export PRODUCTION=1
    else
        export PRODUCTION=0
    fi

    python manage.py runserver 0.0.0.0:8000
}

alias dbshell="python manage.py dbshell"
alias devrunserver="django_runserver false"
alias runserver="django_runserver true"
alias rs="runserver"

shell() {
    python manage.py help debugsqlshell &>/dev/null
    if [ $? -eq 0 ]; then
        python manage.py debugsqlshell
    else
        python manage.py shell
    fi
}

# Replace the `validate' alias, dropped from Django in 1.7.
alias check="python manage.py check"
alias startapp="python manage.py startapp"
alias startproject="python manage.py startproject"
