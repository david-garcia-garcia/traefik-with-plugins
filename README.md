# Traefik Image (with plugins)

[Traefik](https://traefik.io/) image with embeded plugins. 

You need to add plugins to your traefik images because:

* You don't want your Traefik pods not to start when Traefik's plugin repository is down
* Traefik pods start much faster if they don't have to pull the plugins every time they start

See:

* [Embedding plugins beforehand to avoid on-startup compiling - Traefik / Traefik v2 - Traefik Labs Community Forum](https://community.traefik.io/t/embedding-plugins-beforehand-to-avoid-on-startup-compiling/16816/4)
* [traefik/plugindemo: This repository includes an example plugin, for you to use as a reference for developing your own plugins](https://github.com/traefik/plugindemo#local-mode)

To build the image locally use:

```powershell
.\build -StartContainers
```

The project includes a sample traefik.yml

Built images are available at:

[davidbcn86/traefik-with-plugins general | Docker Hub](https://hub.docker.com/repository/docker/davidbcn86/traefik-with-plugins/general)
