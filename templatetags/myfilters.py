from statik.templatetags import register

@register.filter(name='localized_date')
def localized_date(value, lang):
    months = lang.months.split(',')
    month = months[value.month - 1]
    fmt = str(lang.date_format).replace('%b', month)
    return value.strftime(fmt)
