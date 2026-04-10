export const EVENT_PRESETS = [
  {id:'marathon',   label:'Marathon',        icon:'run',color:'#E8604C',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time',distance:'26.2 miles',typicalDuration:'2:30-5:00+'},
  {id:'ultra',      label:'Ultramarathon',   icon:'mountain',color:'#D45A3A',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time',distance:'50K-100mi+',typicalDuration:'4:00-30:00+'},
  {id:'half',       label:'Half Marathon',   icon:'run',color:'#E87840',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time',distance:'13.1 miles',typicalDuration:'1:15-2:30+'},
  {id:'10k',        label:'10K Race',        icon:'run',color:'#F0A830',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time',distance:'6.2 miles',typicalDuration:'30:00-60:00+'},
  {id:'5k',         label:'5K Race',         icon:'run',color:'#F5C030',planType:'run',goalLabel:'Goal time',resultLabel:'Finish time',distance:'3.1 miles',typicalDuration:'15:00-30:00+'},
  {id:'mile',       label:'Mile',            icon:'zap',color:'#E8C040',planType:'run',goalLabel:'Goal time',resultLabel:'Time',distance:'1 mile',typicalDuration:'4:00-8:00'},
  {id:'tri_703',    label:'70.3 Triathlon',  icon:'swim',color:'#2BAFC4',planType:'tri',goalLabel:'Goal time',resultLabel:'Finish time',distance:'1.2mi swim / 56mi bike / 13.1mi run',typicalDuration:'4:00-7:00+'},
  {id:'tri_full',   label:'Full Ironman',    icon:'swim',color:'#2090A8',planType:'tri',goalLabel:'Goal time',resultLabel:'Finish time',distance:'2.4mi swim / 112mi bike / 26.2mi run',typicalDuration:'8:00-17:00'},
  {id:'tri_sprint', label:'Sprint Tri',      icon:'swim',color:'#40C0D0',planType:'tri',goalLabel:'Goal time',resultLabel:'Finish time',distance:'750m swim / 12.4mi bike / 3.1mi run',typicalDuration:'1:00-1:45'},
  {id:'cycling',    label:'Cycling Race',    icon:'bike',color:'#4890D8',planType:'bike',goalLabel:'Goal time',resultLabel:'Finish time'},
  {id:'lift_1rm',   label:'Lifting 1RM',     icon:'dumbbell',color:'#2ABF84',planType:'strength',goalLabel:'Target (lbs)',resultLabel:'Weight'},
  {id:'lift_bw',    label:'Bodyweight Goal', icon:'dumbbell',color:'#30B070',planType:'strength',goalLabel:'Target reps',resultLabel:'Reps'},
  {id:'body',       label:'Body Comp',       icon:'scale',color:'#8B6FE8',planType:'general',goalLabel:'Target',resultLabel:'Result'},
  {id:'custom',     label:'Custom Goal',     icon:'target',color:'#A0A0BC',planType:'general',goalLabel:'Your goal',resultLabel:'Result'},
];
export const presetById = id => EVENT_PRESETS.find(p=>p.id===id)||EVENT_PRESETS.at(-1);

export const SPORT_META = {
  run:{icon:'run',color:'#E8604C',label:'Run'}, bike:{icon:'bike',color:'#2BAFC4',label:'Bike'},
  swim:{icon:'swim',color:'#4890D8',label:'Swim'}, strength:{icon:'dumbbell',color:'#2ABF84',label:'Strength'},
  brick:{icon:'layers',color:'#F0A830',label:'Brick'}, hike:{icon:'mountain',color:'#E87840',label:'Hike'},
  other:{icon:'target',color:'#A0A0BC',label:'Other'},
};

export const BODY_PART_COLORS = {
  Chest:'#E8604C', Back:'#2BAFC4', Shoulders:'#F0A830', Biceps:'#8B6FE8',
  Triceps:'#A855F7', Core:'#2ABF84', Quads:'#E87840', Hamstrings:'#D97706',
  Glutes:'#EC4899', Calves:'#14B8A6', 'Full Body':'#6366F1',
};
export const CATEGORIES = ['Barbell','Dumbbell','Machine','Cable','Bodyweight','Band','Kettlebell','Other'];
export const BODY_PARTS = ['Chest','Back','Shoulders','Biceps','Triceps','Core','Quads','Hamstrings','Glutes','Calves','Full Body'];
