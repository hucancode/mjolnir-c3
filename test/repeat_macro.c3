import std::io;

macro @repeat(seed, $n) {
    $typeof(seed)* ret = ($typeof(seed)*) malloc($typeof(seed).sizeof * $n);
    $for (var $i = 0; $i < $n; $i++)
        ret[$i] = seed;
    $endfor
    return ret[:$n];
}

macro @repeatn(seed, n) {
    $typeof(seed)* ret = ($typeof(seed)*) malloc($typeof(seed).sizeof * n);
    for (var i = 0; i < n; i++) {
        ret[i] = seed;
    }
    return ret[:n];
}

fn void testMacro() @test {
    int seed = 10;
    int[] arr = @repeat(seed, 5);
    defer free(arr);
    int n = 3;
    int[] arr2 = @repeatn(seed, n);
    defer free(arr2);
    foreach(x:arr) assert(x == seed);
}
