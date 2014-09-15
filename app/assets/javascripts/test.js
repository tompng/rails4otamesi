$(function(){
  var lists = {
    root: 'root',
    root_name: 'root.name',
    branch_one: 'root.branch_one',
    branch_one_name: 'root.branch_one.name',
    branch_many: 'root.branch_manies.*',
    branch_many_name: 'root.branch_manies.*.name',
    leaf_one_one: 'root.branch_one.leaf_one',
    leaf_one_one_name: 'root.branch_one.leaf_one.name',
    leaf_one_many: 'root.branch_one.leaf_manies.*',
    leaf_one_many_name: 'root.branch_one.leaf_manies.*.name',
    leaf_many_one: 'root.branch_manies.*.leaf_one',
    leaf_many_one_name: 'root.branch_manies.*.leaf_one.name',
    leaf_many_many: 'root.branch_manies.*.leaf_manies.*',
    leaf_many_many_name: 'root.branch_manies.*.leaf_manies.*.name',
    leaf_many_many_json_rand: 'root.branch_manies.*.leaf_manies.*.json.rand'
  }


  NotificationEvent.on('root', function(){
  })

  NotificationEvent.on('root.name', function(){
  })

  NotificationEvent.on('root','name', function(){
  })


})
