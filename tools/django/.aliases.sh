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
    # Serve on every interface on port 8000 by default.
    # Usage:
    #   $ runserver
    #   $ runserver 8080
    #   $ runserver 127.0.0.1:8080
    production="${1}"
    address="${2:-}"

    if "${production}" 2>/dev/null; then
        export PRODUCTION=1
    else
        export PRODUCTION=0
    fi

    # Expand a bare port to a full address so only the port has to be typed.
    if [[ -z "${address}" ]]; then
        address="0.0.0.0:8000"
    elif [[ "${address}" != *:* ]]; then
        address="0.0.0.0:${address}"
    fi

    python manage.py runserver "${address}"
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
