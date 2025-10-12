# Image de base Jenkins LTS
FROM jenkins/jenkins:lts

# Passer en mode root pour installer des paquets
USER root

# Mise à jour et installation des outils nécessaires
RUN apt-get update && apt-get install -y \
    git \
    curl \
    docker.io \
    unzip \
    openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

# Installer le scanner SonarQube (CLI)
RUN mkdir -p /opt/sonar-scanner && \
    curl -sSL https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-5.0.1.3006-linux.zip -o /tmp/sonar.zip && \
    unzip /tmp/sonar.zip -d /opt && \
    mv /opt/sonar-scanner-5.0.1.3006-linux/* /opt/sonar-scanner && \
    rm -rf /tmp/sonar.zip

# Ajouter le scanner SonarQube dans le PATH
ENV PATH="$PATH:/opt/sonar-scanner/bin"

# Donner accès au socket Docker
RUN groupadd -for docker && usermod -aG docker jenkins

# Revenir à l'utilisateur Jenkins
USER jenkins

# Exposer le port de Jenkins
EXPOSE 8080

# Dossier Jenkins
VOLUME /var/jenkins_home
