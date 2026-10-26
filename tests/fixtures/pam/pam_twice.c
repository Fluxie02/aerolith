/* Test-only PAM module for tests/scenarios/lock-multistep.sh: asks for two
 * hidden answers in a row (a password, then a second factor) and succeeds
 * only when both equal its argument. Built and installed into the throwaway
 * test container by tools/headless/run.sh (LOCK_PAM=double); never shipped.
 * A client that answers only one hidden prompt must fail; one that sends the
 * password again to the second prompt would succeed, so the scenario sees it.
 */
#include <security/pam_ext.h>
#include <security/pam_modules.h>
#include <stdlib.h>
#include <string.h>

static int ask(pam_handle_t *pamh, const char *prompt, const char *want) {
	char *resp = NULL;
	int ok = pam_prompt(pamh, PAM_PROMPT_ECHO_OFF, &resp, "%s", prompt) == PAM_SUCCESS
	         && resp != NULL && strcmp(resp, want) == 0;
	free(resp);
	return ok;
}

int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
	(void)flags;
	if (argc != 1) return PAM_AUTH_ERR;
	if (!ask(pamh, "Password: ", argv[0])) return PAM_AUTH_ERR;
	if (!ask(pamh, "Second factor: ", argv[0])) return PAM_AUTH_ERR;
	return PAM_SUCCESS;
}

int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
	(void)pamh; (void)flags; (void)argc; (void)argv;
	return PAM_SUCCESS;
}
