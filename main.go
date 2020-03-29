package main

import (
	"fmt"
	"github.com/manifoldco/promptui"
	log "github.com/sirupsen/logrus"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"os"
	"os/user"
)

type OpenstackContextConfig struct {
	CurrentContext string             `yaml:"current_context"`
	Contexts       []OpenstackContext `yaml:"contexts"`
}

type OpenstackContext struct {
	Name                string `yaml:"name"`
	OsProjectDomainName string `yaml:"os_project_domain_name"`
	OsUserDomainName    string `yaml:"os_user_domain_name"`
	OsProjectId         string `yaml:"os_project_id"`
	OsUsername          string `yaml:"os_username"`
	OsPassword          string `yaml:"os_password"`
	OsAuthUrl           string `yaml:"os_auth_url"`
	OsRegionName        string `yaml:"os_region_name"`
}

func main() {
	// retrieve and parse configuration file
	path := getConfigPath()
	f, err := ioutil.ReadFile(path)
	if err != nil {
		log.Error(fmt.Sprintf("Could not open %s", path))
		os.Exit(1)
	}
	config := OpenstackContextConfig{}
	err = yaml.Unmarshal(f, &config)
	if err != nil {
		log.Error("Invalid configuration file syntax")
	}

	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "current-context":
			fmt.Printf(config.CurrentContext)
			os.Exit(0)
		case "activate":
			for _, context := range config.Contexts {
				if context.Name == os.Args[2] {
					ActivateContext(&config, context)
				}
			}
			fmt.Printf("Could not find context \"%s\".\n", os.Args[2])
			os.Exit(1)
		default:
			fmt.Println("Unexpected argument")
			os.Exit(1)
		}
	}

	// otherwise prompt for context selection
	SelectContext(config)
}

func SelectContext(openstackConfig OpenstackContextConfig) {
	contextsNames := make([]string, len(openstackConfig.Contexts))
	contextsMap := make(map[string]OpenstackContext)
	for i, context := range openstackConfig.Contexts {
		contextsNames[i] = context.Name
		contextsMap[context.Name] = context
	}

	prompt := promptui.Select{
		Label:        "Select Openstack context",
		Items:        contextsNames,
		HideSelected: true,
		Stdout:       os.Stderr,
	}
	_, selectedContext, err := prompt.Run()
	if err != nil {
		fmt.Printf("Unable to start prompt %v\n", err)
		return
	}
	ActivateContext(&openstackConfig, contextsMap[selectedContext])
}

func ActivateContext(openstackConfig *OpenstackContextConfig, context OpenstackContext) {
	_ = os.Setenv("OS_AUTH_URL", context.OsAuthUrl)
	_ = os.Setenv("OS_PROJECT_ID", context.OsProjectId)
	_ = os.Setenv("OS_PROJECT_DOMAIN_NAME", context.OsProjectDomainName)
	_ = os.Setenv("OS_USER_DOMAIN_NAME", context.OsUserDomainName)
	_ = os.Setenv("OS_USERNAME", context.OsUsername)
	_ = os.Setenv("OS_PASSWORD", context.OsPassword)
	_ = os.Setenv("OS_REGION_NAME", context.OsRegionName)
	path := getConfigPath()
	openstackConfig.CurrentContext = context.Name
	data, _ := yaml.Marshal(openstackConfig)
	err := ioutil.WriteFile(path, data, 0600)
	if err != nil {
		log.Error("Could not write to %s", path)
	}
	fmt.Printf(`export OS_AUTH_URL="%s";export OS_PROJECT_ID="%s";export OS_PROJECT_DOMAIN_NAME="%s";export OS_USER_DOMAIN_NAME="%s";export OS_USERNAME="%s";export OS_PASSWORD="%s";export OS_REGION_NAME="%s"`,
		context.OsAuthUrl,
		context.OsProjectId,
		context.OsProjectDomainName,
		context.OsUserDomainName,
		context.OsUsername,
		context.OsPassword,
		context.OsRegionName)
	os.Exit(0)
}

func getConfigPath() string {
	u, err := user.Current()
	if err != nil {
		log.Error("Could not retrieve current user information")
		os.Exit(1)
	}
	return fmt.Sprintf("%s/.openstack/config", u.HomeDir)
}
