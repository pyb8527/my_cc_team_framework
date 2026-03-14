@echo off
echo Installing all plugins from my_cc_team_framework...

claude plugin install understand-repo@my_cc_team_framework
claude plugin install backend-developer@my_cc_team_framework
claude plugin install frontend-developer@my_cc_team_framework
claude plugin install dba@my_cc_team_framework
claude plugin install qa@my_cc_team_framework
claude plugin install ui-ux-designer@my_cc_team_framework
claude plugin install pm@my_cc_team_framework
claude plugin install planner@my_cc_team_framework
claude plugin install pl@my_cc_team_framework

echo Done! Restart Claude Code to use the plugins.
pause
