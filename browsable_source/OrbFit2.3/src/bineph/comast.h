* Copyright (C) 1997 by Mario Carpino (carpino@brera.mi.astro.it)
* Version: March 9, 1997
* ---------------------------------------------------------------------
* Masses of massive asteroids and number of asteroids
* nbm         -  number of massive objects
* nba         -  number of massless objects
* nbt         -  total number of objects (nbm+nba)
* gmsun       -  G*M(Sun)
* gma         -  G*M(planet)
* gma1        -  G*M(Sun+planet)
* astmas      -  M(planet)
* astnam      -  Object names
*
      INTEGER nbm,nba,nbt
      DOUBLE PRECISION gmsun,gma,gma1,astmas
      CHARACTER*30 astnam
      COMMON/cmmas1/nbm,nba,nbt
      COMMON/cmmas2/gmsun,gma(nbmx),gma1(nbmx),astmas(nbmx)
      COMMON/cmmas3/astnam(nbmx)
