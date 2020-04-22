{ nixpkgs ? import <nixpkgs> {}
}:

with nixpkgs;
stdenv.mkDerivation {
  name = "connectal";
  version = "1.0.0";
  buildInputs = [
    bluespec
    strace
    gmp
    (python.withPackages (p: with p; [ ply gevent ]))
    Literate
  ];

  CONNECTALDIR = toString ./connectal;

  BLUESPECDIR = let
    bsc-contrib = stdenv.mkDerivation {
      name = "bsc-contrib-unstable";
      version = "2020-02-22";
      src = fetchFromGitHub {
        owner = "B-Lang-org";
        repo = "bsc-contrib";
        rev = "24f84b19ef1260f9171eef25945940c6cf030836";
        sha256 = "1xfgwia3b34b9j74qjm5m1cd5hfi4vnw5kgn7l33glgxmqvigv28";
      };
      buildInputs = [ bluespec ];
      makeFlags = [ "PREFIX=$(out)" ];
    };
    libraries = symlinkJoin {
      name = "bluespec-libraries";
      paths = [ bluespec bsc-contrib ];
    };
  in "${libraries}/lib";
}
