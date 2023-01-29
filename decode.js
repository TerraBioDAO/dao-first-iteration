import bs58 from "bs58";

const code = "1220481F1EE0FCD05B418073BB6C53CA10FCDBAB235766D2D94378CC1E4015C3329D";

const main = () => {
  const hashBytes = Buffer.from(code, "hex");
  console.log(bs58.encode(hashBytes));
};

main();
