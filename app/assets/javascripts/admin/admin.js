'use strict';

var modules = modules || {};

modules.admin = (function () {
var module = {}

module.dataTree = null;

module.init = function() {
  module.initElements();
}

module.initElements = function() {
  // FIXME: 最初は上階層しか表示せずに、下階層はAjaxで取得できるようにしたい
  // http://final.hateblo.jp/entry/2016/01/13/212400
  $('#folder-tree').jstree({ 'core' : {
    'themes': {'stripes':true},
    // 'data' : [
    //    { "id" : "ajson1", "parent" : "#", "text" : "Simple root node" },
    //    { "id" : "ajson2", "parent" : "#", "text" : "Root node 2" },
    //    { "id" : "ajson3", "parent" : "ajson2", "text" : "Child 1" },
    //    { "id" : "ajson4", "parent" : "ajson2", "text" : "Child 2" },
    //    { "id" : "ajson6", "parent" : "#", "text" : "Origin" },
    //    { "id" : "ajson7", "parent" : "ajson6", "text" : "file" },
    //    { "id" : "ajson8", "parent" : "ajson7", "text" : "file" },
    // ]
    'data': module.dataTree,
  } });

  $('#folder-tree').on("changed.jstree", function (e, data) {
    var file_data = [];
    // object that represents the DIV for the jsTree
    var objTreeView = $("#folder-tree");
    // returns a list of <li> ID's that have been sected by the user
    var selectedNodes = objTreeView.jstree(true).get_selected();
    // This is the best way to loop object in javascript
    for (var i = 0; i < selectedNodes.length; i++) {
      // get the actual node object from the <li> ID
      var full_node = objTreeView.jstree(true).get_node(selectedNodes[i]);
      // Get the full path of the selected node and put it into an array
      file_data[i] = objTreeView.jstree(true).get_path(full_node, "/");
    }
    // Convert the array to a JSON string so that we can pass the data back to the server 
    // once the user submits the form data
    console.log(JSON.stringify(file_data));
  });

}

return module;
}());