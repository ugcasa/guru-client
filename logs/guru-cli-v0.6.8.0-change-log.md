0.6.8.0
'lazy maggot'

# 0.6.8. 'lazy maggot' features

## 0) new version file

Can handle features list in 'version' file.
reads first line as version number $GURU_VERSION
and second as name $GURU_VERSION_NAME.

Feels like natural location to write down version changes
and keep simple feature checklists.

As an root level file can easily read by script.

I'll try it, lets see.

**todo:**

- [x] change done
- [ ] try it
    - [ ] like it
    - [ ] hate it


## 1) modules can run stand alone by default

Modules need to be able to run without .gururc.
Exception is core level modules,
those have veto do shit ever they want.

**todo:**

- [x] bash -x
- [ ] learn how it works now ;D
- [ ] **rc clean up**
- [ ] .gururc is generated badly
- [ ] re- write config.sh


## 2) next bad idea