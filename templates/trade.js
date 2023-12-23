const {{company.abbreviation}}{{trade.name}} = Agreement.constructor({{company.abbreviation}}, "{{trade.name}}")
  .setTask([{{#task}}
    {{.}}
  {{/task}}])
  .setReward([{{#reward}}
    {{.}}
  {{/reward}}]){{#recurrence}}
  .setRecurrence({{.}}){{/recurrence}}
  .create()
