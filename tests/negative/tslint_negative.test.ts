function validRange (range: any) {
   return range.min <= range.middle && range.middle <= range.max;
}

const RANGE_ = {
   min: 5,
   middle: 10,
   max: 20
};

any test_var = 10;

test_var |= 1;