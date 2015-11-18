def upgrade ta, td, a, d
  a['upgrade_one_shot'] = ta['upgrade_one_shot']
  d['element_states'] = td['element_states']
  d['element_order'] = td['element_order']
  d['element_run_list_order'] = td['element_run_list_order']
  return a, d
end

def downgrade ta, td, a, d
  a.delete('upgrade_one_shot')
  d['element_states'] = td['element_states']
  d['element_order'] = td['element_order']
  d['element_run_list_order'] = td['element_run_list_order']
  return a, d
end

