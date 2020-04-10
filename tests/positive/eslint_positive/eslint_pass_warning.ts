function identity<T>(arg: T): T {
    return arg;
}

function idem<T>(arg: T): T {
    const one = 1;
    console.log(one);
    return arg;
}

idem(identity(null));
