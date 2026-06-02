# ctf/challenges/pivot/Containerfile
#
# Set YOUR OWN FLAGS before building.
# Replace PIVOT_FLAG_1 and PIVOT_FLAG_2 with your chosen flag values.
#
# Example:
#   PIVOT_FLAG_1=flag{ssh_pivot_master_2024}
#   PIVOT_FLAG_2=flag{lateral_movement_pro}
#
# Build with: nerdctl build -t ctf-pivot:latest .

FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash player && \
    echo "player:PIVOT_FLAG_1" | chpasswd

RUN useradd -m -s /bin/bash pivotuser && \
    usermod -aG sudo pivotuser

RUN echo "PIVOT_FLAG_2" > /root/root_flag.txt && \
    chmod 600 /root/root_flag.txt

RUN mkdir /var/run/sshd
RUN echo "PermitRootLogin no" >> /etc/ssh/sshd_config
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
