extends Actor

func act():
	state = States.ACTING
	var action = $MainStrat.act(self)
	if action != null:
		action.connect("finished", self, "finalize_turn", [], CONNECT_ONESHOT)
	else:
		finalize_turn()
	return action
	
