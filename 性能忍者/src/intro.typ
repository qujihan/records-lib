#import "../lib.typ":*

= 简介以及安装

- #link(
    "https://faculty.cs.niu.edu/~winans/notes/patmc.pdf",
    "英文原版（https://faculty.cs.niu.edu/~winans/notes/patmc.pdf）",
  )
- #link(
    "https://github.com/xiaoweiChen/Performance-Analysis-and-Tuning-on-Modern-CPUS-2ed",
    "中文翻译（https://github.com/xiaoweiChen/Performance-Analysis-and-Tuning-on-Modern-CPUS-2ed）",
  )
- #link("https://github.com/dendibakh/perf-ninja", "Github仓库（https://github.com/dendibakh/perf-ninja）")

== 使用Docker
#code-figure("运行容器", [
```bash
docker run -it --name perf-ninja -v ${HOME}/.ssh:/root/.ssh/ ubuntu:24.04
```
])

#code-figure("安装步骤", [

```bash
# 修改为清华大学镜像源
echo "Types: deb" > /etc/apt/sources.list.d/ubuntu.sources
echo "URIs: http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports" >> /etc/apt/sources.list.d/ubuntu.sources
echo "Suites: noble noble-updates noble-backports" >> /etc/apt/sources.list.d/ubuntu.sources
echo "Components: main restricted universe multiverse" >> /etc/apt/sources.list.d/ubuntu.sources
echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg" >> /etc/apt/sources.list.d/ubuntu.sources

# 安装依赖
export DEBIAN_FRONTEND=noninteractive
apt update; apt install -y curl wget git ninja-build make cmake lsb-release software-properties-common gnupg
wget https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh 17 all

# 设置 clang 为默认编译器
update-alternatives --install /usr/bin/cc cc /usr/bin/clang-17 30
update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-17 30

# 安装 google benchmark
git clone git@github.com:google/benchmark.git; cd benchmark;
git checkout v1.9.2
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DBENCHMARK_DOWNLOAD_DEPENDENCIES=on -G Ninja
cmake --build build --config Release --target install

# 下载代码
cd; git clone git@github.com:dendibakh/perf-ninja.git
# 进入相应的 Lab 目录
# cd labs/core_bound/compiler_intrinsics_1/
cmake -B build -S . -G Ninja; cmake --build build
```
])