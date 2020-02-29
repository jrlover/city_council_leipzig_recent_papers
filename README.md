Scraper for https://ratsinfo.leipzig.de/

The scraped data is eventually displayed by [stadtratmonitor.leipzig.codefor.de](https://stadtratmonitor.leipzig.codefor.de/)
which is developed [here](https://github.com/CodeforLeipzig/stadtratmonitor).

This is a scraper that runs on [Morph](https://morph.io/jrlover/city_council_leipzig_recent_papers). 
To get started, see the [documentation](https://morph.io/documentation).

Install docker:
`curl -fsSL https://get.docker.com/ | sh`

If you encounter any troubles, follow the installation guide at [the official Docker site](https://docs.docker.com/engine/installation/).

Build docker image:
`docker build -t leipzig_scraper .`

Use docker image to execute scraper:
Calling `docker run leipzig_scraper` will process `https://ratsinfo.leipzig.de/bi/vo020.asp?VOLFDNR=1003952` by default, 
with `docker run leipzig_scraper scraper.rb https://ratsinfo.leipzig.de/bi/vo020.asp?VOLFDNR=1003952` you can process any other paper
and with `docker run leipzig_scraper person_scraper.rb https://ratsinfo.leipzig.de/bi/pa021.asp` you can process council members.

Related projects:
* [Scraper for http://ratsinfo.dresden.de](https://github.com/offenesdresden/ratsinfo-scraper), scraped data is stored 
  [here](https://github.com/offenesdresden/dresden-ratsinfo), used by [democropticon](https://github.com/astro/democropticon) to 
  visualize it [here](https://ratskarte.offenesdresden.de/)
* [scraper](https://github.com/okfde/politik-bei-uns-scraper) used by [Politik bei uns](https://politik-bei-uns.de/)
* [scraper](https://github.com/codeformunich/Muenchen-Transparent) used by [München Transparent](https://www.muenchen-transparent.de/)
* [Offener Rat Münster](https://github.com/codeformuenster/offenerrat-ms)
* [Old Leipzig ERIS scraper](https://github.com/CodeforLeipzig/eris-scraper)
* [OParl Specification](https://oparl.org/spezifikation/online-ansicht/)