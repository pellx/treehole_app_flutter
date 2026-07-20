import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('user_device_binding')
@Index('uk_user_device', ['user_id', 'device_id'], { unique: true })
export class UserDeviceBindingEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'int' })
  user_id: number;

  @Index('idx_device_id')
  @Column({ type: 'int' })
  device_id: number;

  /** 用户为该绑定自定义的设备名；空则前端回退 devices.device_name */
  @Column({ type: 'varchar', length: 100, nullable: true, default: null })
  device_display_name: string | null;

  @Column({ type: 'varchar', length: 20, default: 'active' })
  status: string;

  @CreateDateColumn()
  bound_at: Date;

  @Column({ type: 'timestamp', nullable: true, default: null })
  unbind_requested_at: Date;

  @Column({ type: 'timestamp', nullable: true, default: null })
  unbound_at: Date;
}
