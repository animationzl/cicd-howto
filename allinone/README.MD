# Guide of Allinone OpenLab CI deployment

This documentation will show you about how to deploy a "Allinone" OpenLab CI
syetem.

## Steps to deploy

1. prepare a github application, and install the application into the repo you
want to run this CI against.

2. run `common/add_zuul_user.sh` to add a zuul user.

3. Configure the `id`, `token` and the local path of  private key of github app
in the `allinonerc` file, which need you to store the private key file in the
deploying server firstly.

4. Config the cloud authentication credentials into the `allinonerc` file,
including the AUTH_URL, USER_NAME, PASSWORD, etc.

5. Config the public key of `zuul` user of the deployment server in the github
account which include `project-config` and `openlab-zuul-jobs` repos to be used
in this allinone CI.

6. Modify the `main.yaml` file to adapt your self repos info, please note, you
need to keep consistency of the 'exclude-unprotected-branches' option with your
github repos branches configuration.

7. run `allinone.sh` script to install all the components.

8. Modify `project-config` and `openlab-zuul-jobs` to temporarily remove the
usage of `secrets` and commit these changes to remote repos, and then start
`zuul-web` and `zuul-scheduler` services. Then use the encryption tool of under
`zuul/tools` to generate new encrypted strings of the secret contents. e.g.
```
  ./encrypt_secret.py  http://localhost:9000/openlaballinone liu-sheng/project-config --infile /home/zuul/.ssh/id_rsa
```
and then update the new secrets to remote repo.

9 Modify the tenant name of CI("theopenlab" as default) and the "zuul_log_url"
in the `project-config` repo and `openlab-zuul-jobs` repo and then update to
remote repos.

10. Restart all the zuul services by running the `restart_zuul.sh` with zuul
user.
