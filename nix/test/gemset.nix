{
  appraisal2 = {
    dependencies = ["rake" "thor"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "12iipiw1i3575gwqyin35d04d4bvisvxjkgdpggn1qcz9d0d4r36";
      type = "gem";
    };
    version = "3.2.6";
  };
  backports = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dbjl5ilyzlhl4p60pq41kdy4j8bg21f4m1vccawlh1wvhr8sacl";
      type = "gem";
    };
    version = "3.25.3";
  };
  delegate = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "01d8ksyj5bannbls9zh9i207wf9x9rb5h8csz6zkvv8bsa9i33q5";
      type = "gem";
    };
    version = "0.7.0";
  };
  diff-lcs = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0qlrj2qyysc9avzlr4zs1py3x684hqm61n4czrsk1pyllz5x5q4s";
      type = "gem";
    };
    version = "1.6.2";
  };
  kettle-test = {
    dependencies = ["appraisal2" "backports" "rspec" "rspec-block_is_expected" "rspec-pending_for" "rspec-stubbed_env" "rspec_junit_formatter" "silent_stream" "timecop-rspec" "turbo_tests2" "version_gem"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0n9ify1wrwzf5chs791saw5qwlzflqqd50vpdb4clgxfgji82k53";
      type = "gem";
    };
    version = "2.0.29";
  };
  logger = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "00q2zznygpbls8asz5knjvvj2brr3ghmqxgr83xnrdj4rk3xwvhr";
      type = "gem";
    };
    version = "1.7.0";
  };
  rake = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "009p524zl0p0kfa65nii8wdmaigkmawv9pbvlcffky7islmmp0nb";
      type = "gem";
    };
    version = "13.4.2";
  };
  rspec = {
    dependencies = ["rspec-core" "rspec-expectations" "rspec-mocks"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "11q5hagj6vr694innqj4r45jrm8qcwvkxjnphqgyd66piah88qi0";
      type = "gem";
    };
    version = "3.13.2";
  };
  rspec-block_is_expected = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10j2yxpvmv875h9zdjxm58hnwzzkynzx2gyb9p7vx4xs1v1kvbdv";
      type = "gem";
    };
    version = "1.0.6";
  };
  rspec-core = {
    dependencies = ["rspec-support"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0saldf4kdq8d6fipcnfjq8bj9hkwv2vg98y6rc2rh4c8jxnz2ky6";
      type = "gem";
    };
    version = "3.13.7";
  };
  rspec-expectations = {
    dependencies = ["diff-lcs" "rspec-support"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0d9gs81alv270yxfx8082g6z4f301ifdnzx8hl6mpzv7sfk8qlxz";
      type = "gem";
    };
    version = "3.13.6";
  };
  rspec-mocks = {
    dependencies = ["diff-lcs" "rspec-support"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0c1acydkadw3r27vx07glfldasgc1bwcxairc359hq2a0prpyp7a";
      type = "gem";
    };
    version = "3.13.9";
  };
  rspec-pending_for = {
    dependencies = ["rspec-core" "ruby_engine" "ruby_version"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1wzfm7z09qkqmjwy5y6p051vzrinslq8km21fkp9i0sj5gpsr6f4";
      type = "gem";
    };
    version = "0.1.28";
  };
  rspec-stubbed_env = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0lnws0qzfkbq3viq2c81kjnsdzy08y0z1fb1wj6v0hmplqx62cbf";
      type = "gem";
    };
    version = "1.0.17";
  };
  rspec-support = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1mpzl1c5537wd36h4m1g2rvwbz2xlchfgpv3k2fkwzlv60q005p4";
      type = "gem";
    };
    version = "3.13.8";
  };
  rspec_junit_formatter = {
    dependencies = ["rspec-core"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "084s4zy2zdzfxv7giqzzg697shmk7v63459nr25jjgbig555sl1c";
      type = "gem";
    };
    version = "0.8.0";
  };
  ruby_engine = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ala4zx6gdq271n2bh2x4h1v9j2rbmnx71m1nszw5kfgz3gffana";
      type = "gem";
    };
    version = "2.0.3";
  };
  ruby_version = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1dfcy4bz7kgmp4i7kvqg2w5l9rsf6vp9hhqqfg4ydds60yazjc2r";
      type = "gem";
    };
    version = "1.0.3";
  };
  runtime_groups = {
    dependencies = ["version_gem"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0babfqwc58l9zicvrhnvjpwxa7dy2mhm544py7aazajyc03qhq6r";
      type = "gem";
    };
    version = "0.1.3";
  };
  silent_stream = {
    dependencies = ["logger" "version_gem"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10p778ghkwsnzj75kpsn90f2v7ypjz6si7mk6c6fjgq322m46z1p";
      type = "gem";
    };
    version = "1.0.12";
  };
  thor = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wsy88vg2mazl039392hqrcwvs5nb9kq8jhhrrclir2px1gybag3";
      type = "gem";
    };
    version = "1.5.0";
  };
  timecop = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0hkmrkg46qvfla31734d5y28q422z5kfgb41yy2227q4wp34sa21";
      type = "gem";
    };
    version = "0.9.11";
  };
  timecop-rspec = {
    dependencies = ["delegate" "rspec" "timecop"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fgsk3jl16ls7a5ywavl6yaybql8acdk43h6zfpdq1mn3f218pq0";
      type = "gem";
    };
    version = "1.0.3";
  };
  turbo_tests2 = {
    dependencies = ["rspec" "runtime_groups" "version_gem"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1gdf57s19gwfrga8bymr493d7ykg6q8fv3yapi33k5yaxqljw750";
      type = "gem";
    };
    version = "4.0.0";
  };
  version_gem = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1zcdb8y8zhcwlz0m851vwmdx4kfxh1jyvf3ygrz7mdzvfnb0nhkh";
      type = "gem";
    };
    version = "1.1.17";
  };
}
